# Anti-phishing claim: the Speaker hands the browser here with a signed handoff; the browser must prove it
# controls a local Ace (fresh password or fresh claim-only Google), see both the Ace and the requesting
# Speaker, and confirm before a single-use receipt is minted for the Speaker's server-to-server exchange.
class RizzAuth::ClaimsController < ApplicationController
  include RizzAuth::CookieHelper

  COOKIE = "rizz_claim_local".freeze

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
    return claim_rejected unless RizzClaimHandoff.acceptable?(claims)

    handoff, token = RizzClaimHandoff.start!(claims)
    delete_rizz_cookie RizzAuth::CreationsController::COOKIE # a browser never holds both flows' cookies
    write_rizz_cookie COOKIE, { "handoff_id" => handoff.id, "token" => token }, expires_in: RizzClaimHandoff::LIFETIME
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
  # Google subject counts; no email matching and no account creation. A browser in the Create flow reuses this
  # callback to optionally prove its Google account (see #create_google_callback).
  def google_callback
    auth = request.env["omniauth.auth"]
    uid = RizzAuth::GoogleProof.verified_uid(auth)
    return create_google_callback(auth, uid) if @create_flow

    ace = Ace.find_by(google_uid: uid) if uid
    return prove_failed "Google couldn't confirm an account linked to AthleteAce. Try picking the linked Google account or use your password instead." unless ace
    return prove_failed "That account can't be connected right now." unless claimable?(ace)

    @handoff.prove! ace
    redirect_to rizz_claim_confirm_path, status: :see_other
  end

  def google_failure
    message = "Google sign-in was cancelled or could not be completed."
    if cookie_handoff(COOKIE)&.claim_intent? || !cookie_handoff(RizzAuth::CreationsController::COOKIE)&.create_intent?
      redirect_to rizz_claim_prove_path, status: :see_other, alert: message
    else
      redirect_to rizz_create_path, status: :see_other, alert: message
    end
  end

  def confirm
    @ace = @handoff.verified_ace
  end

  def connect
    receipt = nil
    @handoff.with_lock do
      ace = @handoff.verified_ace
      next unless @handoff.claim_intent? && @handoff.usable? && @handoff.proven? && claimable?(ace) &&
        RizzSignIn.configuration.issuer_origin?(@handoff.callback_uri) && @handoff.consume!

      receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: @handoff.operation_id)
    end
    return claim_rejected unless receipt

    delete_rizz_cookie COOKIE
    redirect_to @handoff.return_url(receipt), allow_other_host: true, status: :see_other
  end

  def cancel
    @handoff.consume!
    delete_rizz_cookie COOKIE
    redirect_to root_path, status: :see_other, notice: "Nothing was connected."
  end

  private

  # The Claim cookie first. Only the Google callback also accepts the Create cookie, for the optional "Link Google now".
  def load_handoff
    if (handoff = cookie_handoff(COOKIE))&.claim_intent?
      @handoff = handoff
    elsif action_name == "google_callback" && (handoff = cookie_handoff(RizzAuth::CreationsController::COOKIE))&.create_intent?
      @handoff, @create_flow = handoff, true
    else
      claim_rejected "This connect link expired or was opened in a different browser. Start again from Rizz."
    end
  end

  # The usable handoff whose browser token matches the named cookie, whatever its intent.
  def cookie_handoff(cookie)
    data = read_rizz_cookie(cookie)
    handoff = RizzClaimHandoff.find_by(id: data["handoff_id"]) if data.is_a?(Hash) && data["token"].is_a?(String)
    handoff if handoff&.usable? && ActiveSupport::SecurityUtils.secure_compare(handoff.browser_token_digest, RizzClaimHandoff.digest(data["token"]))
  end

  # Create flow: Google only proves control of the verified email's Google account so it can be linked once the
  # Ace is created. It never signs in, links by email, calls Ace.from_google, or creates an Ace.
  def create_google_callback(auth, uid)
    unless uid && auth.dig("info", "email_verified") == true
      return create_google_rejected "Google couldn't verify that account. Try again, or create your account without linking Google now."
    end

    google_email = auth.dig("info", "email").to_s.strip.downcase
    handoff_email = nil
    outcome = @handoff.with_lock do
      next :gone unless @handoff.create_intent? && @handoff.usable?

      handoff_email = @handoff.email
      next :email_mismatch unless google_email == handoff_email

      if Ace.exists?(google_uid: uid)
        @handoff.switch_to_claim!
        :existing_ace
      else
        @handoff.update!(google_uid: uid)
        :attached
      end
    end

    case outcome
    when :gone
      claim_rejected
    when :email_mismatch
      create_google_rejected "Choose the Google account matching #{masked_email(handoff_email)}, or create your account without linking Google now."
    when :existing_ace
      token = read_rizz_cookie(RizzAuth::CreationsController::COOKIE)["token"]
      delete_rizz_cookie RizzAuth::CreationsController::COOKIE
      write_rizz_cookie COOKIE, { "handoff_id" => @handoff.id, "token" => token }, expires_in: RizzClaimHandoff::LIFETIME
      redirect_to rizz_claim_prove_path, status: :see_other, notice: "That Google account already belongs to an AthleteAce account. Confirm it's you to connect it."
    when :attached
      redirect_to rizz_create_path, status: :see_other, notice: "Google account verified and will be linked when you create your account."
    end
  end

  def create_google_rejected(message)
    redirect_to rizz_create_path, status: :see_other, alert: message
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
