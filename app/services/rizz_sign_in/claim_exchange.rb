module RizzSignIn
  # Server-to-server step of a claim or create: spend the browser's receipt and bind the Ace to the Rizz subject.
  # A create receipt also builds the Ace from its onboarded handoff, in the same transaction.
  # Repeating an operation_id for the same subject returns the same success.
  class ClaimExchange
    Result = Struct.new(:status, :ace)
    Conflict = Class.new(StandardError)
    EmailTaken = Class.new(Conflict)

    def self.call(**args)
      new(**args).call
    end

    def initialize(operation_id:, receipt:, rizz_sub:, rizz_session_epoch:)
      @operation_id, @receipt, @rizz_sub, @epoch = operation_id, receipt, rizz_sub, rizz_session_epoch
    end

    # status: :ok, :invalid (bad or spent receipt), :conflict (already bound elsewhere, or the new Ace's handle is taken),
    # :email_taken (a create receipt's email now belongs to an Ace)
    def call
      result = begin
        ApplicationRecord.transaction { bind }
      rescue ActiveRecord::RecordNotUnique
        replay || Result.new(:conflict)
      rescue EmailTaken
        Result.new(:email_taken)
      rescue Conflict
        Result.new(:conflict)
      end
      @draft&.discard_password! if %i[conflict email_taken].include?(result.status)
      result
    end

    private

    def bind
      return replay if AceRizzBinding.exists?(operation_id: @operation_id)

      receipt = RizzClaimReceipt.find_by_receipt(@receipt)
      return Result.new(:invalid) unless receipt&.usable? && receipt.operation_id == @operation_id

      ace = receipt.ace || new_ace_for(receipt)
      return Result.new(:invalid) if ace.nil? || ace.suspended? || !ace.confirmed?

      by_sub = AceRizzBinding.lock.find_by(rizz_sub: @rizz_sub)
      held = AceRizzBinding.lock.active.find_by(ace_id: ace.id) if ace.persisted?
      return Result.new(:conflict) if (held && held.rizz_sub != @rizz_sub) || (by_sub&.active? && by_sub.ace_id != ace.id)
      return Result.new(:invalid) unless receipt.consume!

      create_ace!(ace, receipt) unless ace.persisted?

      attributes = { ace: ace, operation_id: @operation_id, status: "active", connected_at: Time.current, disconnected_at: nil }
      if by_sub
        by_sub.update!(attributes.merge(rizz_session_epoch: [ by_sub.rizz_session_epoch, @epoch ].max))
      else
        AceRizzBinding.create!(attributes.merge(rizz_sub: @rizz_sub, rizz_session_epoch: @epoch))
      end
      Result.new(:ok, ace)
    end

    # The unsaved Ace a create receipt stands for, once its handoff still holds the onboarded password.
    def new_ace_for(receipt)
      handoff = receipt.handoff
      return unless handoff&.create_intent? && handoff.encrypted_password.present?

      @draft = handoff
      handoff.build_ace
    end

    # Email or handle taken since onboarding: nothing is created or linked, and the whole transaction rolls back.
    def create_ace!(ace, receipt)
      ace.transaction(requires_new: true) { ace.save! }
      receipt.handoff.discard_password!
    rescue ActiveRecord::RecordInvalid => error
      raise(error.record.errors.of_kind?(:email, :taken) ? EmailTaken : Conflict)
    rescue ActiveRecord::RecordNotUnique
      raise(Ace.exists?(email: ace.email) ? EmailTaken : Conflict)
    end

    def replay
      binding = AceRizzBinding.active.find_by(operation_id: @operation_id)
      binding&.rizz_sub == @rizz_sub ? Result.new(:ok, binding.ace) : Result.new(:conflict)
    end
  end
end
