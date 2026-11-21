# Anti-phishing claim: the Speaker hands the browser here with a signed handoff; the browser must prove it
# controls a local Ace (fresh password or fresh claim-only Google), see both the Ace and the requesting
# Speaker, and confirm before a single-use receipt is minted for the Speaker's server-to-server exchange.
class RizzAuth::ClaimsController < ApplicationController
  include RizzAuthCookie

  COOKIE = "rizz_claim_local".freeze
  GOOGLE_PROVIDER = "rizz_claim_google".freeze
  GOOGLE_AUTH_MAX_AGE = 5.minutes
  HANDOFF_LIFETIME = 10.minutes

  skip_before_action :require_ace_identity
  skip_after_action :store_browsing_location
  skip_forgery_protection only: %i[start google_failure] # start is entered from the Speaker; its JWT is the credential
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  before_action :load_handoff, except: %i[start google_failure]
  before_action :require_proof, only: %i[confirm connect]
  rate_limit to: 10, within: 3.minutes, only: :verify_password, with: -> { redirect_to rizz_claim_prove_path, status: :see_other, alert: "Too many attempts. Try again in a few minutes." }

  helper_method :masked_email, :google_proof_enabled?

  def start
    claims = RizzSignIn::TokenVerifier.verify_claim_handoff(params[:handoff])
    return claim_rejected unless RizzSignIn.configuration.issuer_origin?(claims["callback_uri"]) && claims["speaker_label"].length <= 120

    token = SecureRandom.urlsafe_base64(32)
    handoff = RizzClaimHandoff.create!(handoff_jti: claims["jti"], operation_id: claims["operation_id"], speaker_label: claims["speaker_label"],
      callback_uri: claims["callback_uri"], browser_token_digest: RizzClaimHandoff.digest(token), expires_at: HANDOFF_LIFETIME.from_now)
    write_rizz_cookie COOKIE, { "handoff_id" => handoff.id, "token" => token }, expires_in: HANDOFF_LIFETIME
    redirect_to rizz_claim_prove_path, status: :see_other
  rescue RizzSignIn::InvalidToken, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    claim_rejected
  rescue RizzSignIn::Unavailable
    claim_rejected "Rizz is unavailable right now. Please try again from Rizz."
  end

  def prove
    @signed_in_ace = current_ace
  end

  def verify_password
    ace = Ace.find_for_database_authentication(email: params[:email].to_s.strip.downcase) if params[:password].is_a?(String)
    return prove_failed "That email and password didn't match." unless ace&.valid_password?(params[:password])
    return prove_failed "That email and password didn't match." unless claimable?(ace)

    @handoff.prove! ace
    redirect_to rizz_claim_confirm_path, status: :see_other
  end

  # OmniAuth (the claim-only Google strategy, never Devise's) lands here. Only an Ace already linked to this
  # Google subject counts; no email matching and no account creation.
  def google_callback
    auth = request.env["omniauth.auth"]
    id_info = auth&.dig("extra", "id_info")
    iat = id_info&.[]("iat")
    fresh = iat.is_a?(Integer) && iat.between?(GOOGLE_AUTH_MAX_AGE.ago.to_i, 1.minute.from_now.to_i)
    uid = auth&.[]("uid").to_s
    ace = Ace.find_by(google_uid: uid) if auth&.[]("provider").to_s == GOOGLE_PROVIDER && fresh && uid.present? && id_info&.[]("sub") == uid
    return prove_failed "Google couldn't confirm an account linked to AthleteAce. Try picking the linked Google account or use your password instead." unless ace
    return prove_failed "That account can't be connected right now." unless claimable?(ace)

    @handoff.prove! ace
    redirect_to rizz_claim_confirm_path, status: :see_other
  end

  def google_failure
    redirect_to rizz_claim_prove_path, status: :see_other, alert: "Google sign-in was cancelled or could not be completed."
  end

  def confirm
    @ace = @handoff.verified_ace
  end

  def connect
    ace = @handoff.verified_ace
    return claim_rejected unless RizzSignIn.configuration.issuer_origin?(@handoff.callback_uri) && @handoff.consume!

    receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: @handoff.operation_id)
    delete_rizz_cookie COOKIE
    redirect_to "#{@handoff.callback_uri}#{@handoff.callback_uri.include?("?") ? "&" : "?"}#{{ operation_id: @handoff.operation_id, receipt: receipt }.to_query}",
      allow_other_host: true, status: :see_other
  end

  def cancel
    @handoff.consume!
    delete_rizz_cookie COOKIE
    redirect_to root_path, status: :see_other, notice: "Nothing was connected."
  end

  private

  def load_handoff
    data = read_rizz_cookie(COOKIE)
    handoff = RizzClaimHandoff.find_by(id: data["handoff_id"]) if data.is_a?(Hash) && data["token"].is_a?(String)
    if handoff&.usable? && ActiveSupport::SecurityUtils.secure_compare(handoff.browser_token_digest, RizzClaimHandoff.digest(data["token"]))
      @handoff = handoff
    else
      claim_rejected "This connect link expired or was opened in a different browser. Start again from Rizz."
    end
  end

  def require_proof
    return if @handoff.proven? && claimable?(@handoff.verified_ace)

    redirect_to rizz_claim_prove_path, status: :see_other, alert: "Confirm it's you before connecting."
  end

  def claimable?(ace)
    ace.present? && !ace.suspended? && ace.confirmed?
  end

  def prove_failed(message)
    redirect_to rizz_claim_prove_path, status: :see_other, alert: message
  end

  def claim_rejected(message = "That connect link isn't valid. Start again from Rizz.")
    redirect_to new_ace_session_path, status: :see_other, alert: message
  end

  def google_proof_enabled?
    Rails.application.config.x.google_oauth.enabled
  end

  def masked_email(email)
    RizzSignIn.mask_email(email)
  end
end
