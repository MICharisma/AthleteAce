# Account creation from the Rizz Speaker: it hands the browser here with a signed handoff carrying a verified
# Google email. The browser chooses a username, display name and local password; nothing is created in AthleteAce
# until the Speaker spends the receipt (RizzSignIn::ClaimExchange). An email that already has an Ace continues
# as an ordinary Claim, which this controller never proves, links or modifies.
class RizzAuth::CreationsController < ApplicationController
  include RizzAuthCookie

  COOKIE = "rizz_create_local".freeze

  skip_before_action :require_ace_identity
  skip_after_action :store_browsing_location
  skip_forgery_protection only: :start # start is entered from the Speaker; its JWT is the credential
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  before_action :load_handoff, except: :start
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to rizz_create_path, status: :see_other, alert: "Too many attempts. Try again in a few minutes." }

  helper_method :minimum_password_length, :google_proof_enabled?

  def start
    claims = RizzSignIn::TokenVerifier.verify_create_handoff(params[:handoff])
    return create_rejected unless RizzClaimHandoff.acceptable?(claims)

    RizzClaimHandoff.purge_spent_drafts!
    expires_at = Time.zone.at(claims.fetch("exp"))
    if Ace.exists?(email: claims["email"])
      handoff, token = RizzClaimHandoff.start!(claims, expires_at: expires_at)
      continue_as_claim handoff, token
    else
      handoff, token = RizzClaimHandoff.start!(claims, intent: "create", expires_at: expires_at)
      delete_rizz_cookie RizzAuth::ClaimsController::COOKIE # a browser never holds both flows' cookies
      write_rizz_cookie COOKIE, { "handoff_id" => handoff.id, "token" => token }, expires_in: RizzClaimHandoff::LIFETIME
      redirect_to rizz_create_path, status: :see_other
    end
  rescue RizzSignIn::InvalidToken, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    create_rejected
  rescue RizzSignIn::Unavailable
    create_rejected "Rizz is unavailable right now. Please try again from Rizz."
  end

  def new
    @ace = Ace.new(username: @handoff.username.presence || @handoff.suggested_username, display_name: @handoff.display_name)
    @suggested_username_taken = @ace.username.present? &&
      (Ace::RESERVED_USERNAMES.include?(@ace.username.downcase) || Ace.where("LOWER(username) = ?", @ace.username.downcase).exists?)
  end

  def create
    result = RizzSignIn::Onboarding.call(handoff: @handoff, attributes: ace_params)
    case result.status
    when :onboarded
      delete_rizz_cookie COOKIE
      redirect_to @handoff.return_url(result.receipt), allow_other_host: true, status: :see_other
    when :invalid
      @ace = result.ace
      render :new, status: :unprocessable_content
    when :existing_email
      continue_as_claim @handoff, @browser_token
    else
      create_rejected "This link expired or was already used. Start again from Rizz."
    end
  end

  def cancel
    @handoff.cancel_create!
    delete_rizz_cookie COOKIE
    redirect_to root_path, status: :see_other, notice: "Nothing was created."
  end

  private

  def load_handoff
    data = read_rizz_cookie(COOKIE)
    handoff = RizzClaimHandoff.find_by(id: data["handoff_id"]) if data.is_a?(Hash) && data["token"].is_a?(String)
    if handoff&.create_intent? && handoff.usable? && ActiveSupport::SecurityUtils.secure_compare(handoff.browser_token_digest, RizzClaimHandoff.digest(data["token"]))
      @handoff, @browser_token = handoff, data["token"]
    else
      create_rejected "This link expired or was opened in a different browser. Start again from Rizz."
    end
  end

  # The password fields are optional: both blank (or omitted) means a passwordless create.
  def ace_params
    params.expect(ace: %i[username display_name password password_confirmation]).to_h.with_defaults("password" => "", "password_confirmation" => "")
  end

  # The handoff is now an ordinary claim handoff, so hand the browser to the Claim proof with its own cookie.
  def continue_as_claim(handoff, token)
    delete_rizz_cookie COOKIE
    write_rizz_cookie RizzAuth::ClaimsController::COOKIE, { "handoff_id" => handoff.id, "token" => token }, expires_in: RizzClaimHandoff::LIFETIME
    redirect_to rizz_claim_prove_path, status: :see_other, notice: "That email already has an AthleteAce account. Confirm it's you to connect it."
  end

  def create_rejected(message = "That link isn't valid. Start again from Rizz.")
    redirect_to new_ace_session_path, status: :see_other, alert: message
  end

  def google_proof_enabled?
    Rails.application.config.x.google_oauth.enabled
  end

  def minimum_password_length
    Devise.password_length.min
  end
end
