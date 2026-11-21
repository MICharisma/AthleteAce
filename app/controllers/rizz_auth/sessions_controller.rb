class RizzAuth::SessionsController < ApplicationController
  include RizzAuth::CookieHelper

  FLOW_COOKIE = "rizz_auth_flow".freeze

  skip_before_action :require_ace_identity
  skip_after_action :store_browsing_location
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rate_limit to: 10, within: 1.minute, only: %i[create callback], with: -> { rizz_failed "Too many Rizz sign-in attempts. Try again in a minute." }

  def create
    verifier = SecureRandom.urlsafe_base64(48)
    flow = { "state" => SecureRandom.urlsafe_base64(32), "nonce" => SecureRandom.urlsafe_base64(32), "verifier" => verifier }
    write_rizz_cookie FLOW_COOKIE, flow, expires_in: 10.minutes
    redirect_to RizzSignIn::Client.authorization_url(redirect_uri: rizz_auth_callback_url, state: flow["state"], nonce: flow["nonce"],
      code_challenge: RizzSignIn::Client.code_challenge(verifier)), allow_other_host: true, status: :see_other
  rescue RizzSignIn::Error
    rizz_failed "Rizz is unavailable right now. Please try again."
  end

  def callback
    flow = read_rizz_cookie(FLOW_COOKIE)
    delete_rizz_cookie FLOW_COOKIE
    return rizz_failed unless flow.is_a?(Hash) && params[:error].blank? && params[:code].is_a?(String) && params[:state].is_a?(String) &&
      ActiveSupport::SecurityUtils.secure_compare(params[:state], flow["state"].to_s)

    id_token = RizzSignIn::Client.exchange_code(code: params[:code], code_verifier: flow["verifier"], redirect_uri: rizz_auth_callback_url)
    claims = RizzSignIn::TokenVerifier.verify_id_token(id_token, nonce: flow["nonce"])
    binding = AceRizzBinding.active.find_by(rizz_sub: claims["sub"])
    return redirect_to new_ace_session_path, status: :see_other, notice: "That Rizz account isn't connected to an AthleteAce account yet. Connect it from Rizz, or sign in another way." unless binding
    return rizz_failed if claims["rizz_epoch"] < binding.rizz_session_epoch

    ace = binding.ace
    return rizz_failed "Your account can't sign in right now." unless ace.active_for_authentication?

    sign_in :ace, ace, event: :authentication, force: true
    cookies.delete(:remember_ace_token)
    session["rizz_binding_id"] = binding.id
    session["rizz_session_epoch"] = binding.rizz_session_epoch
    SignInEvent.record!(ace, request, outcome: "success")
    redirect_to after_sign_in_path_for(ace), status: :see_other
  rescue RizzSignIn::Unavailable
    rizz_failed "Rizz is unavailable right now. Please try again."
  rescue RizzSignIn::Error
    rizz_failed
  end

  private

  def rizz_failed(message = "Rizz sign-in could not be completed. Please try again.")
    redirect_to new_ace_session_path, status: :see_other, alert: message
  end
end
