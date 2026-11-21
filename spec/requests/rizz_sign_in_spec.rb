require "rails_helper"

RSpec.describe "Sign in with Rizz", type: :request do
  include_context "with a Rizz speaker"

  let(:ace) { create(:ace) }
  let!(:binding) { AceRizzBinding.create!(ace: ace, rizz_sub: "pairwise-sub-1", operation_id: "op-1", rizz_session_epoch: 2, connected_at: Time.current) }

  before { speaker.issue_id_tokens_with(epoch: 2) }

  # Drives POST /auth/rizz, the Speaker's authorize step, and the callback; returns the callback response.
  def sign_in_with_rizz(code_tamper: nil)
    post rizz_auth_path
    expect(response).to have_http_status(:see_other)
    callback_url = speaker.authorize(response.location)
    callback_url = code_tamper.call(callback_url) if code_tamper
    get callback_url
  end

  it "is hidden and returns 404 until it is enabled" do
    with_rizz_env("RIZZ_SIGN_IN_ENABLED" => nil) do
      get new_ace_session_path
      expect(response.body).not_to include("Sign in with Rizz")
      post rizz_auth_path
      expect(response).to have_http_status(:not_found)
      get rizz_auth_callback_path
      expect(response).to have_http_status(:not_found)
    end
    with_rizz_env("RIZZ_OIDC_CLIENT_SECRET" => nil) { expect(RizzSignIn.enabled?).to be(false) }
  end

  it "shows a POST button next to the existing Google and password options" do
    allow(Rails.application.config.x.google_oauth).to receive(:enabled).and_return(true)
    get new_ace_session_path
    page = Nokogiri::HTML(response.body)
    form = page.at_css("form[action='/auth/rizz']")
    expect(form["method"]).to eq("post")
    expect(form.text).to include("Sign in with Rizz")
    expect(response.body).to include("Continue with Google", "ace_password")
  end

  it "starts an S256 PKCE authorization code request with an encrypted HttpOnly flow cookie" do
    post rizz_auth_path
    uri = URI(response.location)
    query = Rack::Utils.parse_query(uri.query)
    expect(uri.to_s).to start_with("https://rizz.test/oauth/authorize?")
    expect(query).to include("client_id" => "athlete-ace-client", "response_type" => "code", "scope" => "openid", "code_challenge_method" => "S256",
      "redirect_uri" => rizz_auth_callback_url)
    expect(query.values_at("state", "nonce", "code_challenge")).to all(be_present)
    cookie = response.headers["set-cookie"]
    expect(cookie).to match(/rizz_auth_flow=/i)
    expect(cookie).to match(/httponly/i)
    expect(cookie).not_to include(query["state"])
  end

  it "signs the bound Ace in without remember-me and marks the session as opened by Rizz" do
    sign_in_with_rizz
    expect(response).to redirect_to("/strength")
    expect(request.env["warden"].user(:ace)).to eq(ace)
    expect(request.session["rizz_binding_id"]).to eq(binding.id)
    expect(request.session["rizz_session_epoch"]).to eq(2)
    expect(response.headers["set-cookie"].to_s).not_to include("remember_ace_token")
    expect(ace.reload.remember_created_at).to be_nil
    expect(SignInEvent.where(ace: ace, outcome: "success").count).to eq(1)
    get profile_path
    expect(response).to have_http_status(:ok)
  end

  it "does not sign in again with a replayed authorization code" do
    sign_in_with_rizz
    callback_url = speaker.codes.values.first[:query]["redirect_uri"]
    delete destroy_ace_session_path
    post rizz_auth_path
    state = Rack::Utils.parse_query(URI(response.location).query)["state"]
    get "#{callback_url}?#{{ code: "already-used-code", state: state }.to_query}"
    expect(response).to redirect_to(new_ace_session_path)
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "rejects a code the Speaker already consumed" do
    sign_in_with_rizz
    used = speaker.codes.values.first
    expect(used[:consumed]).to be(true)
    expect { speaker.post_form("#{RizzSpeaker::ISSUER}/oauth/token", { code: "x" }, basic_auth: %w[a b]) }.to raise_error(RizzSignIn::Unavailable)
  end

  it "rejects a missing flow cookie or a wrong state" do
    post rizz_auth_path
    callback_url = speaker.authorize(response.location)
    reset!
    get callback_url
    expect(response).to redirect_to(new_ace_session_path)
    expect(request.env["warden"].user(:ace)).to be_nil

    post rizz_auth_path
    callback_url = speaker.authorize(response.location)
    get callback_url.sub(/state=[^&]+/, "state=forged")
    expect(response).to redirect_to(new_ace_session_path)
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "does not let the flow cookie be used twice" do
    post rizz_auth_path
    callback_url = speaker.authorize(response.location)
    get callback_url
    expect(request.env["warden"].user(:ace)).to eq(ace)
    delete destroy_ace_session_path
    get callback_url
    expect(response).to redirect_to(new_ace_session_path)
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  {
    "an expired ID token" => { iat: 2.hours.ago.to_i, exp: 1.hour.ago.to_i },
    "an ID token for another audience" => { aud: "someone-else" },
    "an ID token from another issuer" => { iss: "https://evil.example" },
    "an ID token with the wrong nonce" => { nonce_override: "not-the-nonce" },
    "an ID token with the wrong typ" => { typ: "at+jwt" },
    "an ID token missing its epoch" => { rizz_epoch: nil },
    "an ID token signed by an unknown key" => { signing_key: OpenSSL::PKey::EC.generate("prime256v1") },
    "an ID token naming an unknown kid" => { key_id: "not-in-jwks" }
  }.each do |description, overrides|
    it "rejects #{description}" do
      overrides = overrides.dup
      speaker.define_singleton_method(:post_form) do |url, params, basic_auth:|
        super(url, params, basic_auth: basic_auth).merge(
          "id_token" => id_token(nonce: overrides.delete(:nonce_override) || codes.values.last[:query]["nonce"], **overrides))
      end
      sign_in_with_rizz
      expect(response).to redirect_to(new_ace_session_path)
      expect(request.env["warden"].user(:ace)).to be_nil
      expect(SignInEvent.count).to eq(0)
    end
  end

  it "rejects an ID token that is not ES256" do
    speaker.define_singleton_method(:post_form) do |url, params, basic_auth:|
      nonce = codes.values.last[:query]["nonce"]
      super(url, params, basic_auth: basic_auth).merge("id_token" => JWT.encode(base_claims("sub" => "pairwise-sub-1", "nonce" => nonce, "rizz_epoch" => 2),
        "a-shared-secret", "HS256", { typ: "JWT", kid: kid }))
    end
    sign_in_with_rizz
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "rejects an unsigned (alg none) ID token" do
    speaker.define_singleton_method(:post_form) do |url, params, basic_auth:|
      nonce = codes.values.last[:query]["nonce"]
      super(url, params, basic_auth: basic_auth).merge("id_token" => JWT.encode(base_claims("sub" => "pairwise-sub-1", "nonce" => nonce, "rizz_epoch" => 2), nil, "none", { typ: "JWT", kid: kid }))
    end
    sign_in_with_rizz
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "rejects an ID token whose epoch is behind the binding" do
    speaker.issue_id_tokens_with(epoch: 1)
    sign_in_with_rizz
    expect(response).to redirect_to(new_ace_session_path)
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "accepts an ID token from a newer epoch" do
    speaker.issue_id_tokens_with(epoch: 5)
    sign_in_with_rizz
    expect(request.env["warden"].user(:ace)).to eq(ace)
  end

  it "explains when the Rizz account has no active binding" do
    speaker.issue_id_tokens_with(sub: "someone-unbound")
    sign_in_with_rizz
    expect(response).to redirect_to(new_ace_session_path)
    follow_redirect!
    expect(response.body).to include("isn&#39;t connected to an AthleteAce account yet")
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "ignores a disconnected binding" do
    binding.update!(status: "disconnected", disconnected_at: Time.current)
    sign_in_with_rizz
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "does not sign in a suspended or unconfirmed Ace" do
    ace.update!(suspended_at: Time.current)
    sign_in_with_rizz
    expect(request.env["warden"].user(:ace)).to be_nil
    ace.update!(suspended_at: nil, confirmed_at: nil)
    sign_in_with_rizz
    expect(request.env["warden"].user(:ace)).to be_nil
  end

  it "reports an unavailable issuer without signing in" do
    allow(RizzSignIn::HttpClient).to receive(:get_json).and_raise(RizzSignIn::Unavailable)
    RizzSignIn::JwksClient.reset!
    post rizz_auth_path
    expect(response).to redirect_to(new_ace_session_path)
  end

  it "requires a Rails CSRF token to start" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post rizz_auth_path
    expect(response.location.to_s).not_to start_with(RizzSpeaker::ISSUER)
    expect(speaker.fetches).to be_empty
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  it "leaves password sign-in unaffected, even with a stale Rizz marker in the session" do
    other = create(:ace, email: "direct@example.com", password: "password123")
    post ace_session_path, params: { ace: { email: other.email, password: "password123" } }
    get profile_path
    expect(response).to have_http_status(:ok)
    expect(request.env["warden"].user(:ace)).to eq(other)
    expect(request.session["rizz_binding_id"]).to be_nil
  end
end
