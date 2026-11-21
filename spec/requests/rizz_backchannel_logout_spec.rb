require "rails_helper"

RSpec.describe "Rizz back-channel logout", type: :request do
  include_context "with a Rizz speaker"

  let(:ace) { create(:ace) }
  let!(:binding) { AceRizzBinding.create!(ace: ace, rizz_sub: "pairwise-sub-1", operation_id: "op-1", rizz_session_epoch: 2) }

  def logout(token)
    post "/auth/rizz/backchannel_logout", params: { logout_token: token }
  end

  def sign_in_with_rizz
    speaker.issue_id_tokens_with(epoch: binding.reload.rizz_session_epoch)
    post rizz_auth_path
    get speaker.authorize(response.location)
    expect(request.env["warden"].user(:ace)).to eq(ace)
  end

  it "bumps the epoch, marks the binding disconnected, and returns 200" do
    logout speaker.logout_token(epoch: 2)
    expect(response).to have_http_status(:ok)
    expect(binding.reload).to have_attributes(status: "disconnected", rizz_session_epoch: 3)
    expect(binding.disconnected_at).to be_present
    expect(RizzBackchannelLogoutEvent.last).to have_attributes(rizz_sub: "pairwise-sub-1", rizz_epoch: 2)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "jumps to the token's epoch when that is ahead" do
    logout speaker.logout_token(epoch: 7)
    expect(binding.reload.rizz_session_epoch).to eq(7)
  end

  it "applies a redelivered jti only once" do
    token = speaker.logout_token(epoch: 2, jti: "same-jti")
    logout token
    logout token
    expect(response).to have_http_status(:ok)
    expect(binding.reload.rizz_session_epoch).to eq(3)
    expect(RizzBackchannelLogoutEvent.count).to eq(1)
  end

  it "never lowers the epoch" do
    logout speaker.logout_token(epoch: 1)
    expect(binding.reload.rizz_session_epoch).to eq(3)
  end

  it "acknowledges a subject with no binding" do
    logout speaker.logout_token(sub: "unknown-sub")
    expect(response).to have_http_status(:ok)
    expect(binding.reload).to have_attributes(status: "active", rizz_session_epoch: 2)
  end

  {
    "a bad signature" => { signing_key: OpenSSL::PKey::EC.generate("prime256v1") },
    "an expired token" => { iat: 2.hours.ago.to_i, exp: 1.hour.ago.to_i },
    "another audience" => { aud: "other-client" },
    "another issuer" => { iss: "https://evil.example" },
    "the wrong typ" => { typ: "JWT" },
    "no logout event" => { events: {} },
    "a nonce claim" => { nonce: "forbidden" },
    "no jti" => { jti: nil },
    "no epoch" => { rizz_epoch: nil }
  }.each do |description, overrides|
    it "rejects #{description} with 400 and changes nothing" do
      overrides = overrides.dup
      typ = overrides.delete(:typ)
      logout speaker.logout_token(**{ typ: typ }.compact, **overrides)
      expect(response).to have_http_status(:bad_request)
      expect(binding.reload).to have_attributes(status: "active", rizz_session_epoch: 2)
      expect(RizzBackchannelLogoutEvent.count).to eq(0)
    end
  end

  it "rejects a missing token and an ID token used as a logout token" do
    post "/auth/rizz/backchannel_logout"
    expect(response).to have_http_status(:bad_request)
    logout speaker.id_token(nonce: "n")
    expect(response).to have_http_status(:bad_request)
  end

  it "needs no session, cookie, or CSRF token" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    logout speaker.logout_token(epoch: 2)
    expect(response).to have_http_status(:ok)
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  it "signs a Rizz-opened session out on its next request" do
    sign_in_with_rizz
    get profile_path
    expect(response).to have_http_status(:ok)

    logout speaker.logout_token(epoch: 3)
    expect(response).to have_http_status(:ok)

    get profile_path
    expect(response).to redirect_to(new_ace_session_path)
    expect(request.env["warden"].user(:ace)).to be_nil
    expect(request.session["rizz_binding_id"]).to be_nil
  end

  it "signs out when only the epoch is behind, even if the binding was reactivated" do
    sign_in_with_rizz
    binding.update!(rizz_session_epoch: 5)
    get profile_path
    expect(response).to redirect_to(new_ace_session_path)
  end

  it "signs out when the binding is disconnected" do
    sign_in_with_rizz
    binding.update!(status: "disconnected")
    get profile_path
    expect(response).to redirect_to(new_ace_session_path)
  end

  it "signs out when the binding row is gone or belongs to another Ace" do
    sign_in_with_rizz
    binding.update_columns(ace_id: create(:ace).id)
    get profile_path
    expect(response).to redirect_to(new_ace_session_path)
  end

  it "does not touch a password session for the same Ace" do
    post ace_session_path, params: { ace: { email: ace.email, password: "password123" } }
    get profile_path
    expect(response).to have_http_status(:ok)
    logout speaker.logout_token(epoch: 3)
    get profile_path
    expect(response).to have_http_status(:ok)
    expect(request.env["warden"].user(:ace)).to eq(ace)
  end

  it "does not touch a Google-opened session for the same Ace" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "g-1", info: { email: ace.email, email_verified: true, name: "T" })
    post ace_google_oauth2_omniauth_authorize_path
    follow_redirect!
    expect(request.env["warden"].user(:ace)).to eq(ace)
    logout speaker.logout_token(epoch: 3)
    get profile_path
    expect(response).to have_http_status(:ok)
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  it "lets the Ace sign in with Rizz again after a fresh claim at the new epoch" do
    logout speaker.logout_token(epoch: 3)
    speaker.issue_id_tokens_with(epoch: 3)
    post rizz_auth_path
    get speaker.authorize(response.location)
    expect(request.env["warden"].user(:ace)).to be_nil
    binding.reload.update!(status: "active", disconnected_at: nil)
    post rizz_auth_path
    get speaker.authorize(response.location)
    expect(request.env["warden"].user(:ace)).to eq(ace)
  end
end
