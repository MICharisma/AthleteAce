# Server-to-server OpenID back-channel logout from the Rizz Speaker (logout_token form field).
class RizzAuth::BackchannelLogoutsController < ActionController::API
  def create
    claims = RizzSignIn::TokenVerifier.verify_logout_token(params[:logout_token])
    RizzSignIn::BackchannelLogout.call(claims)
    response.headers["Cache-Control"] = "no-store"
    head :ok
  rescue RizzSignIn::InvalidToken
    render json: { error: "invalid_request" }, status: :bad_request
  rescue RizzSignIn::Unavailable
    head :service_unavailable
  end
end
