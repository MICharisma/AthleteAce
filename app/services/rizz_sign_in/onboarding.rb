module RizzSignIn
  # Browser step of creating an account from Rizz: validate the chosen username, display name and optional password
  # against the verified handoff's email, then spend the handoff and issue the receipt in one transaction.
  # No Ace is saved here. The Speaker's server-to-server exchange builds it after its own cookie-bound check.
  class Onboarding
    Result = Struct.new(:status, :ace, :receipt)

    def self.call(**args)
      new(**args).call
    end

    def initialize(handoff:, attributes:)
      @handoff, @attributes = handoff, attributes
    end

    # status: :onboarded (receipt issued), :invalid (ace carries the errors), :existing_email (handoff continues
    # as a claim), :gone (expired, spent or no longer a create handoff)
    def call
      RizzClaimHandoff.transaction(requires_new: true) { onboard } || Result.new(:gone)
    end

    private

    def onboard
      @handoff.lock!
      return Result.new(:existing_email) if @handoff.claim_intent? && @handoff.usable?
      return Result.new(:gone) unless @handoff.usable? && RizzSignIn.configuration.issuer_origin?(@handoff.callback_uri)

      ace = Ace.new(@attributes.merge(password_attributes).merge(email: @handoff.email, google_uid: @handoff.google_uid))
      ace.skip_confirmation!
      return rejected(ace) unless ace.valid?

      @handoff.onboard! ace
      @handoff.consume! or raise ActiveRecord::Rollback
      Result.new(:onboarded, ace, RizzClaimReceipt.issue!(handoff: @handoff, operation_id: @handoff.operation_id))
    end

    # Leaving both password fields blank is a passwordless 1-click create: the Ace gets a random internal password
    # (the owner can sign in with Google or Rizz, or reset it by email). Typing into either field runs normal validation.
    def password_attributes
      password, confirmation = @attributes["password"].to_s, @attributes["password_confirmation"].to_s
      return { "password" => password, "password_confirmation" => confirmation } unless password.empty? && confirmation.empty?

      generated = Devise.friendly_token(32)
      { "password" => generated, "password_confirmation" => generated }
    end

    def rejected(ace)
      return Result.new(:invalid, ace) unless ace.errors.of_kind?(:email, :taken) || ace.errors.of_kind?(:google_uid, :taken)

      @handoff.switch_to_claim!
      Result.new(:existing_email)
    end
  end
end
