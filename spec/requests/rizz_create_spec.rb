require "rails_helper"

RSpec.describe "Rizz create", type: :request do
  include_context "with a Rizz speaker"

  let(:callback_uri) { "#{RizzSpeaker::ISSUER}/claims/op-1/return" }
  let(:email) { "marcus.tate@gmail.com" }
  let(:onboarding) { { ace: { username: "marcus_tate", display_name: "Marcus Tate", password: "hardwood-9", password_confirmation: "hardwood-9" } } }

  def start_create(**overrides)
    post rizz_create_start_path, params: { handoff: speaker.create_handoff(callback_uri: callback_uri, email: email, **overrides) }
  end

  def submit(attributes = onboarding)
    post rizz_create_path, params: attributes
  end

  def redirect_path(session)
    expect(session.response).to have_http_status(:see_other)
    URI(session.response.location).path
  end

  def set_cookies
    Array(response.headers["set-cookie"]).join("\n")
  end

  def receipt_from_redirect
    Rack::Utils.parse_query(URI(response.location).query).fetch("receipt")
  end

  def exchange(receipt:, operation_id: "op-1", rizz_sub: "pairwise-sub-1", epoch: 3, headers: rizz_basic_auth)
    post "/auth/rizz/claim/exchange", params: { operation_id: operation_id, receipt: receipt, rizz_sub: rizz_sub, rizz_session_epoch: epoch }.to_json,
      headers: headers.merge("Content-Type" => "application/json")
  end

  describe "start" do
    it "verifies the handoff, stores the verified email server-side, and sets an encrypted HttpOnly create cookie" do
      expect { start_create(email: "  Marcus.Tate@Gmail.com ") }.not_to change(Ace, :count)
      expect(response).to redirect_to(rizz_create_path)
      handoff = RizzClaimHandoff.last
      expect(handoff).to have_attributes(intent: "create", operation_id: "op-1", speaker_label: "Marcus T. (Rizz)", callback_uri: callback_uri,
        email: "marcus.tate@gmail.com", display_name: "Marcus Tate", encrypted_password: nil, verified_ace_id: nil, consumed_at: nil)
      cookie = set_cookies
      expect(cookie).to match(/rizz_create_local=/)
      expect(cookie).to match(/httponly/i)
      expect(cookie).not_to include(handoff.id)
      expect(cookie).not_to match(/rizz_claim_local=/)
    end

    it "uses a __Host- cookie under HTTPS" do
      https!
      start_create
      expect(set_cookies).to match(/__Host-rizz_create_local=.*secure/i)
    end

    it "expires the handoff with the signed exp, never later than the normal claim lifetime" do
      start_create(exp: Time.now.to_i + 120)
      expect(RizzClaimHandoff.last.expires_at).to be_within(5.seconds).of(2.minutes.from_now)
      reset!
      start_create(jti: "full", exp: Time.now.to_i + 300)
      expect(RizzClaimHandoff.last.expires_at).to be_within(5.seconds).of(5.minutes.from_now)
    end

    it "refuses onboarding once the signed exp has passed" do
      start_create(exp: Time.now.to_i + 120)
      RizzClaimHandoff.last.update!(expires_at: 1.second.ago)
      submit
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimReceipt.count).to eq(0)
    end

    it "is POST-only" do
      get "/auth/rizz/create/start", params: { handoff: speaker.create_handoff(callback_uri: callback_uri) }
      expect(response).to have_http_status(:not_found)
      expect(RizzClaimHandoff.count).to eq(0)
    end

    it "accepts the cross-site POST without a CSRF token, while onboarding and cancel still require one" do
      ActionController::Base.allow_forgery_protection = true
      start_create
      expect(response).to redirect_to(rizz_create_path)
      submit
      expect(response).to have_http_status(:unprocessable_content)
      post rizz_create_cancel_path
      expect(response).to have_http_status(:unprocessable_content)
      expect(RizzClaimHandoff.last.consumed_at).to be_nil
      expect(RizzClaimReceipt.count).to eq(0)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "refuses a replayed handoff jti, even after it was spent" do
      jwt = speaker.create_handoff(callback_uri: callback_uri, jti: "one-use", email: email)
      post rizz_create_start_path, params: { handoff: jwt }
      submit
      reset!
      post rizz_create_start_path, params: { handoff: jwt }
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimHandoff.count).to eq(1)
    end

    {
      "a bad signature" => { signing_key: OpenSSL::PKey::EC.generate("prime256v1") },
      "an expired handoff" => { iat: 2.hours.ago.to_i, exp: 1.hour.ago.to_i },
      "a lifetime over five minutes" => { iat: Time.now.to_i - 5, exp: Time.now.to_i + 296 + 10 },
      "another audience" => { aud: "other-client" },
      "another issuer" => { iss: "https://evil.example" },
      "a callback on another origin" => { callback_uri: "https://evil.example/claims/op-1/return" },
      "a plain http callback" => { callback_uri: "http://rizz.test/claims/op-1/return" },
      "a callback with credentials" => { callback_uri: "https://user:pass@rizz.test/claims/op-1/return" },
      "an overlong speaker label" => { speaker_label: "M" * 121 },
      "no email" => { email: "" },
      "a non-string email" => { email: [ "marcus.tate@gmail.com" ] },
      "a malformed email" => { email: "not-an-email" },
      "a non-string display name" => { display_name: 42 },
      "an overlong display name" => { display_name: "M" * 61 }
    }.each do |description, overrides|
      it "rejects #{description}" do
        start_create(**overrides)
        expect(response).to redirect_to(new_ace_session_path)
        expect(RizzClaimHandoff.count).to eq(0)
      end
    end

    it "rejects a claim handoff, an ID token, and a missing or non-string handoff" do
      [ speaker.claim_handoff(callback_uri: callback_uri).then { it }, speaker.id_token(nonce: "n") ].each do |token|
        post rizz_create_start_path, params: { handoff: token }
        expect(response).to redirect_to(new_ace_session_path)
      end
      post rizz_create_start_path
      expect(response).to redirect_to(new_ace_session_path)
      post rizz_create_start_path, params: { handoff: { jti: "x" } }
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimHandoff.count).to eq(0)
    end

    it "does not let the claim start accept a create handoff" do
      post rizz_claim_start_path, params: { handoff: speaker.create_handoff(callback_uri: callback_uri) }
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimHandoff.count).to eq(0)
    end

    it "does not log the raw handoff or password" do
      io = StringIO.new
      logger = ActiveSupport::Logger.new(io)
      original = Rails.logger
      Rails.logger = logger
      ActionController::Base.logger = logger
      jwt = speaker.create_handoff(callback_uri: callback_uri)
      post rizz_create_start_path, params: { handoff: jwt }
      submit
      expect(io.string).not_to include(jwt, "hardwood-9", email)
    ensure
      Rails.logger = original
      ActionController::Base.logger = original
    end
  end

  describe "onboarding form" do
    before { start_create }

    it "shows the verified email read-only, with editable handle and display name and an optional collapsed password, over a no-Turbo form" do
      get rizz_create_path
      page = Nokogiri::HTML(response.body)
      form = page.at_css("form[action='#{rizz_create_path}']")
      expect(form["data-turbo"]).to eq("false")
      expect(form.at_css("input[type=email][readonly]")["value"]).to eq(email)
      expect(form.at_css("input[name='ace[username]']")["readonly"]).to be_nil
      expect(form.at_css("input[name='ace[display_name]']")["value"]).to eq("Marcus Tate")
      details = form.at_css("details")
      expect(details.at_css("summary").text).to eq("Set a password (optional)")
      expect(details["open"]).to be_nil
      %w[password password_confirmation].each do |field|
        input = details.at_css("input[name='ace[#{field}]'][type=password]")
        expect(input).to be_present
        expect(input["required"]).to be_nil
      end
      expect(form.at_css("input[type=submit]")["value"]).to eq("Create account")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(page.at_css("form[action='#{rizz_create_cancel_path}']").text).to include("Cancel")
    end

    it "ignores a posted email" do
      submit ace: onboarding[:ace].merge(email: "someone.else@example.com")
      expect(RizzClaimHandoff.last.email).to eq(email)
      expect(RizzClaimReceipt.last.handoff).to eq(RizzClaimHandoff.last)
    end
  end

  describe "happy path" do
    it "builds nothing until the Speaker spends the receipt, then creates a confirmed, independently usable Ace with the Rizz binding" do
      start_create
      get rizz_create_path
      expect { submit }.not_to change(Ace, :count)
      expect(response).to have_http_status(:see_other)
      uri = URI(response.location)
      query = Rack::Utils.parse_query(uri.query)
      expect("#{uri.scheme}://#{uri.host}#{uri.path}").to eq(callback_uri)
      expect(query["operation_id"]).to eq("op-1")
      stored = RizzClaimReceipt.last
      expect(stored).to have_attributes(ace_id: nil, handoff: RizzClaimHandoff.last, operation_id: "op-1", consumed_at: nil)
      expect(stored.receipt_digest).to eq(Digest::SHA256.hexdigest(query["receipt"]))
      expect(stored.expires_at).to be_within(5.seconds).of(60.seconds.from_now)
      handoff = RizzClaimHandoff.last
      expect(handoff.consumed_at).to be_present
      expect(handoff.encrypted_password).to match(/\A\$2/)
      expect(set_cookies).to match(/rizz_create_local=;|rizz_create_local=$/)
      expect(request.env["warden"].user(:ace)).to be_nil

      receipt = query["receipt"]
      reset!
      exchange(receipt: receipt)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("ok" => true, "local_handle" => "@marcus_tate", "has_independent_recovery" => true)
      ace = Ace.find_by!(email: email)
      expect(ace).to have_attributes(username: "marcus_tate", display_name: "Marcus Tate", google_uid: nil, suspended_at: nil)
      expect(ace).to be_confirmed
      expect(ace.valid_password?("hardwood-9")).to be(true)
      expect(AceRizzBinding.last).to have_attributes(ace_id: ace.id, rizz_sub: "pairwise-sub-1", operation_id: "op-1", status: "active", rizz_session_epoch: 3)
      expect(handoff.reload.encrypted_password).to be_nil
      expect(stored.reload.consumed_at).to be_present

      exchange(receipt: receipt)
      expect(response).to have_http_status(:ok)
      expect(Ace.where(email: email).count).to eq(1)
      expect(AceRizzBinding.count).to eq(1)
    end

    it "gives the new Ace independent AthleteAce sign-in with its email and password, and signs in through Rizz too" do
      start_create
      submit
      receipt = receipt_from_redirect
      reset!
      exchange(receipt: receipt)
      reset!

      post ace_session_path, params: { ace: { email: email, password: "hardwood-9" } }
      expect(request.env["warden"].user(:ace)).to have_attributes(email: email, username: "marcus_tate")
      expect(request.session["rizz_binding_id"]).to be_nil
      delete destroy_ace_session_path

      post ace_session_path, params: { ace: { email: email, password: "wrong-password" } }
      expect(request.env["warden"].user(:ace)).to be_nil
    end

    it "does not sign the browser in, even when it is signed in as someone else" do
      other = create(:ace)
      sign_in other
      start_create
      submit
      expect(request.env["warden"].user(:ace)).to eq(other)
      expect(other.reload).to have_attributes(email: other.email)
    end
  end

  describe "validation errors" do
    before { start_create }

    it "re-renders without spending the handoff, and a corrected retry succeeds" do
      create(:ace, username: "marcus_tate")
      submit
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Username has already been taken")
      expect(RizzClaimHandoff.last).to have_attributes(consumed_at: nil, encrypted_password: nil)
      expect(RizzClaimReceipt.count).to eq(0)
      expect(response.body).not_to include("hardwood-9")
      expect(Nokogiri::HTML(response.body).at_css("form[action='#{rizz_create_path}']")["data-turbo"]).to eq("false")

      submit ace: onboarding[:ace].merge(username: "marcus_t")
      expect(response).to have_http_status(:see_other)
      expect(response.location).to start_with(callback_uri)
    end

    {
      "a mismatched password confirmation" => { password_confirmation: "different-1" },
      "a missing password confirmation" => { password_confirmation: nil },
      "a password shorter than Devise allows" => { password: "abc", password_confirmation: "abc" },
      "a password without its confirmation" => { password_confirmation: "" },
      "a confirmation without its password" => { password: "" },
      "a blank display name" => { display_name: " " },
      "a reserved username" => { username: "admin" },
      "an invalid username" => { username: "Marcus T!" }
    }.each do |description, change|
      it "rejects #{description}" do
        submit ace: onboarding[:ace].merge(change).compact
        expect(response).to have_http_status(:unprocessable_content)
        expect(RizzClaimHandoff.last.consumed_at).to be_nil
        expect(RizzClaimReceipt.count).to eq(0)
      end
    end
  end

  describe "passwordless create" do
    let(:passwordless) { { ace: { username: "marcus_tate", display_name: "Marcus Tate" } } }

    def create_and_exchange(attributes)
      start_create
      submit attributes
      expect(response).to have_http_status(:see_other)
      receipt_from_redirect.tap { |receipt| reset!.then { exchange(receipt: receipt) } }
    end

    it "creates a confirmed Ace in one click when the password fields are omitted or blank, with a random internal password" do
      [ passwordless, { ace: passwordless[:ace].merge(password: "", password_confirmation: "") } ].each_with_index do |attributes, index|
        reset!
        start_create(jti: "one-click-#{index}", operation_id: "op-#{index}", email: "one.click#{index}@example.com")
        submit ace: attributes[:ace].merge(username: "one_click_#{index}")
        expect(response.location).to start_with(callback_uri)
        digest = RizzClaimHandoff.order(:created_at).last.encrypted_password
        expect(digest).to match(/\A\$2/)
        receipt = receipt_from_redirect
        reset!
        exchange(receipt: receipt, operation_id: "op-#{index}", rizz_sub: "sub-#{index}")
        expect(response).to have_http_status(:ok)
        ace = Ace.find_by!(email: "one.click#{index}@example.com")
        expect(ace).to be_confirmed
        expect(ace.valid_password?("")).to be(false)
        expect(ace.encrypted_password).to eq(digest)
      end
    end

    it "lets the Ace sign in with Google directly after the Rizz binding is disconnected" do
      create_and_exchange(passwordless)
      expect(response).to have_http_status(:ok)
      AceRizzBinding.last.update!(status: "disconnected", disconnected_at: Time.current)
      auth = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "google-direct-1", info: { email: email, email_verified: true, name: "Marcus Tate" })
      ace = Ace.from_google(auth)
      expect(ace).to have_attributes(email: email, username: "marcus_tate", google_uid: "google-direct-1")
      expect(Ace.where(email: email).count).to eq(1)
    end

    it "runs normal password validation as soon as either password field is filled" do
      start_create
      { password: "hardwood-9", password_confirmation: "hardwood-9" }.each_key do |filled|
        other = filled == :password ? :password_confirmation : :password
        submit ace: passwordless[:ace].merge(filled => "hardwood-9", other => "")
        expect(response).to have_http_status(:unprocessable_content)
      end
      expect(RizzClaimReceipt.count).to eq(0)
    end

    it "opens the password section when its validation fails, and a corrected password works for direct sign-in after disconnect" do
      start_create
      submit ace: passwordless[:ace].merge(password: "abc", password_confirmation: "abc")
      expect(response).to have_http_status(:unprocessable_content)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("details[open] input[name='ace[password]']")).to be_present
      expect(RizzClaimHandoff.last).to have_attributes(consumed_at: nil, encrypted_password: nil)

      submit ace: passwordless[:ace].merge(password: "hardwood-9", password_confirmation: "different-1")
      expect(Nokogiri::HTML(response.body).at_css("details[open] input[name='ace[password_confirmation]']")).to be_present

      submit ace: passwordless[:ace].merge(password: "hardwood-9", password_confirmation: "hardwood-9")
      receipt = receipt_from_redirect
      reset!
      exchange(receipt: receipt)
      AceRizzBinding.last.update!(status: "disconnected", disconnected_at: Time.current)
      post ace_session_path, params: { ace: { email: email, password: "hardwood-9" } }
      expect(request.env["warden"].user(:ace)).to have_attributes(email: email, username: "marcus_tate")
    end

    it "keeps the password section closed when the form re-renders for a non-password error" do
      create(:ace, username: "marcus_tate")
      start_create
      submit passwordless
      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("details[open]")).to be_nil
    end
  end

  describe "handle and display name defaults" do
    it "prefills the handle from the signed username and the display name from the signed display_name" do
      start_create(username: "Marcus_T", display_name: "Marcus Tate")
      expect(RizzClaimHandoff.last).to have_attributes(suggested_username: "marcus_t", username: nil)
      get rizz_create_path
      form = Nokogiri::HTML(response.body).at_css("form[action='#{rizz_create_path}']")
      expect(form.at_css("input[name='ace[username]']")["value"]).to eq("marcus_t")
      expect(form.at_css("input[name='ace[display_name]']")["value"]).to eq("Marcus Tate")
      expect(response.body).not_to include("already taken")
    end

    it "leaves the handle empty without a suggestion" do
      start_create(username: "")
      expect(RizzClaimHandoff.last.suggested_username).to be_nil
      get rizz_create_path
      expect(Nokogiri::HTML(response.body).at_css("input[name='ace[username]']")["value"]).to be_nil
    end

    it "warns inline when the suggested handle is already taken on AthleteAce, in any case" do
      create(:ace, username: "marcus_t")
      start_create(username: "Marcus_T")
      get rizz_create_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("@marcus_t is already taken on AthleteAce")
      expect(Nokogiri::HTML(response.body).at_css("input[name='ace[username]']")["value"]).to eq("marcus_t")
    end

    it "treats rizz and micharisma as reserved and warns about them" do
      expect(Ace::RESERVED_USERNAMES).to include("rizz", "micharisma")
      start_create(username: "Rizz")
      get rizz_create_path
      expect(response.body).to include("@rizz is already taken")
      submit ace: { username: "micharisma", display_name: "Marcus Tate" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Username is reserved")
    end

    it "rejects an invalid suggested handle at start" do
      %w[ab marcus-t].each do |username|
        start_create(username: username)
        expect(response).to redirect_to(new_ace_session_path)
      end
      expect(RizzClaimHandoff.count).to eq(0)
    end
  end

  describe "optional Google link" do
    let(:uid) { "google-link-1" }

    around do |example|
      previous = [ OmniAuth.config.test_mode, OmniAuth.config.mock_auth[:rizz_claim_google] ]
      OmniAuth.config.test_mode = true
      example.run
    ensure
      OmniAuth.config.test_mode, OmniAuth.config.mock_auth[:rizz_claim_google] = previous
    end

    before { allow(Rails.application.config.x.google_oauth).to receive(:enabled).and_return(true) }

    def link_google(uid: self.uid, google_email: email, iat: Time.now.to_i, id_sub: uid, provider: "rizz_claim_google", verified: true)
      OmniAuth.config.mock_auth[:rizz_claim_google] = OmniAuth::AuthHash.new(provider: provider, uid: uid,
        info: { email: google_email, email_verified: verified, name: "Marcus" }, extra: { id_info: { sub: id_sub, iat: iat }.compact })
      post "/auth/rizz/claim/google"
      expect(response).to redirect_to("http://www.example.com/auth/rizz/claim/google/callback")
      follow_redirect!
    end

    it "offers a collapsed Link Google now button outside the form that reuses the claim Google path, and hides it when Google is off" do
      start_create
      get rizz_create_path
      page = Nokogiri::HTML(response.body)
      details = page.css("details").find { it.at_css("summary").text == "Link Google now (optional)" }
      expect(details["open"]).to be_nil
      expect(page.at_css("form[action='#{rizz_create_path}']").at_css("form[action='/auth/rizz/claim/google']")).to be_nil
      button_form = details.at_css("form[action='/auth/rizz/claim/google']")
      expect(button_form["method"]).to eq("post")
      expect(button_form["data-turbo"]).to eq("false")
      expect(button_form.at_css("button, input[type=submit]").then { it["value"] || it.text }).to eq("Link Google account now")

      allow(Rails.application.config.x.google_oauth).to receive(:enabled).and_return(false)
      get rizz_create_path
      expect(response.body).not_to include("Link Google")
    end

    it "binds a verified matching Google account to the handoff without creating or signing in an Ace, then to the Ace at exchange" do
      expect(Ace).not_to receive(:from_google)
      start_create
      expect { link_google }.not_to change(Ace, :count)
      expect(response).to redirect_to(rizz_create_path)
      expect(flash[:notice]).to eq("Google account verified and will be linked when you create your account.")
      expect(RizzClaimHandoff.last).to have_attributes(google_uid: uid, intent: "create", consumed_at: nil)
      expect(request.env["warden"].user(:ace)).to be_nil

      follow_redirect!
      expect(response.body).to include("Google account verified — will be linked for direct sign-in.")
      expect(response.body).not_to include("Link Google account now")

      submit
      receipt = receipt_from_redirect
      reset!
      exchange(receipt: receipt)
      expect(response).to have_http_status(:ok)
      expect(Ace.find_by!(email: email)).to have_attributes(google_uid: uid)
      expect(RizzClaimHandoff.last.google_uid).to be_nil
    end

    it "lets an Ace created with a linked Google account sign in with Google after Rizz is disconnected" do
      start_create
      link_google
      submit ace: onboarding[:ace].except(:password, :password_confirmation)
      receipt = receipt_from_redirect
      reset!
      exchange(receipt: receipt)
      AceRizzBinding.last.update!(status: "disconnected", disconnected_at: Time.current)
      auth = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: uid, info: { email: email, email_verified: true, name: "Marcus" })
      expect(Ace.from_google(auth)).to eq(Ace.find_by!(email: email))
    end

    it "rejects a Google account for another email and links nothing" do
      start_create
      link_google(google_email: "someone.else@gmail.com")
      expect(response).to redirect_to(rizz_create_path)
      expect(flash[:alert]).to eq("Choose the Google account matching #{RizzSignIn.mask_email(email)}, or create your account without linking Google now.")
      expect(RizzClaimHandoff.last.google_uid).to be_nil
      expect(Ace.count).to eq(0)
    end

    it "matches the Google email regardless of case and whitespace" do
      start_create
      link_google(google_email: " Marcus.Tate@GMAIL.com ")
      expect(RizzClaimHandoff.last.google_uid).to eq(uid)
    end

    {
      "a stale iat" => { iat: 10.minutes.ago.to_i },
      "a missing iat" => { iat: nil },
      "a mismatched id token subject" => { id_sub: "someone-else" },
      "another provider" => { provider: "google_oauth2" },
      "an unverified email" => { verified: false }
    }.each do |description, options|
      it "does not link a Google proof with #{description}" do
        start_create
        link_google(**options)
        expect(response).to redirect_to(rizz_create_path)
        expect(flash[:alert]).to be_present
        expect(RizzClaimHandoff.last.google_uid).to be_nil
        expect(Ace.count).to eq(0)
      end
    end

    it "steers a Google account that already belongs to an Ace to the Claim proof, never calling Ace.from_google or creating an Ace" do
      owner = create(:ace, username: "hoops_marcus", email: "owner@example.com", google_uid: uid)
      expect(Ace).not_to receive(:from_google)
      start_create
      expect { link_google(google_email: "owner@example.com") }.not_to change(Ace, :count)
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(flash[:notice]).to eq("That Google account already belongs to an AthleteAce account. Confirm it's you to connect it.")
      expect(RizzClaimHandoff.last).to have_attributes(intent: "claim", email: nil, display_name: nil, suggested_username: nil, google_uid: nil, verified_ace_id: nil)
      expect(set_cookies).to match(/rizz_claim_local=[^;]/)
      expect(owner.reload.google_uid).to eq(uid)
      expect(owner.active_rizz_binding).to be_nil

      get rizz_create_path
      expect(response).to redirect_to(new_ace_session_path)
      get rizz_claim_prove_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Marcus T. (Rizz)")
    end

    it "returns to the Create form when Google is cancelled, and to the claim proof for a claim browser" do
      start_create
      OmniAuth.config.mock_auth[:rizz_claim_google] = :access_denied
      post "/auth/rizz/claim/google"
      follow_redirect!
      expect(response).to redirect_to(rizz_create_path)
      expect(RizzClaimHandoff.last.google_uid).to be_nil

      reset!
      post rizz_claim_start_path, params: { handoff: speaker.claim_handoff(callback_uri: callback_uri) }
      post "/auth/rizz/claim/google"
      follow_redirect!
      expect(response).to redirect_to(rizz_claim_prove_path)

      reset!
      post "/auth/rizz/claim/google"
      follow_redirect!
      expect(response).to redirect_to(rizz_claim_prove_path)
    end

    it "refuses the Google callback without either cookie, or with a cookie that does not match" do
      start_create
      attacker = open_session
      OmniAuth.config.mock_auth[:rizz_claim_google] = OmniAuth::AuthHash.new(provider: "rizz_claim_google", uid: uid,
        info: { email: email, email_verified: true }, extra: { id_info: { sub: uid, iat: Time.now.to_i } })
      attacker.post "/auth/rizz/claim/google"
      attacker.follow_redirect!
      expect(redirect_path(attacker)).to eq(new_ace_session_path)
      expect(RizzClaimHandoff.last.google_uid).to be_nil

      RizzClaimHandoff.last.update!(browser_token_digest: RizzClaimHandoff.digest("another browser"))
      post "/auth/rizz/claim/google"
      follow_redirect!
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimHandoff.last.google_uid).to be_nil
    end

    it "does not attach Google to a spent or expired handoff" do
      start_create
      handoff = RizzClaimHandoff.last
      handoff.update!(expires_at: 1.second.ago)
      expect(handoff.attach_google!(uid)).to be_nil
      expect(handoff.reload.google_uid).to be_nil
      expect(RizzClaimHandoff.new(intent: "claim", expires_at: 1.minute.from_now).attach_google!(uid)).to be_nil
    end

    it "switches to the claim when the linked Google account is taken before the form is submitted" do
      start_create
      link_google
      create(:ace, google_uid: uid)
      expect { submit }.not_to change(Ace, :count)
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(RizzClaimHandoff.last).to have_attributes(intent: "claim", google_uid: nil, suggested_username: nil, email: nil, consumed_at: nil)
      expect(RizzClaimReceipt.count).to eq(0)
    end

    it "answers 409 email_taken and creates nothing when the linked Google account is taken after the receipt" do
      start_create
      link_google
      submit
      receipt = receipt_from_redirect
      reset!
      create(:ace, google_uid: uid)
      expect { exchange(receipt: receipt) }.not_to change(Ace, :count)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("error" => "email_taken")
      expect(AceRizzBinding.count).to eq(0)
      expect(RizzClaimReceipt.last.consumed_at).to be_nil
    end

    it "answers 409 when the unique index rejects a Google account that validation did not see" do
      start_create
      link_google
      submit
      receipt = receipt_from_redirect
      reset!
      create(:ace, google_uid: uid)
      allow_any_instance_of(Ace).to receive(:valid?).and_return(true)
      expect { exchange(receipt: receipt) }.not_to change(Ace, :count)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("error" => "email_taken")
      expect(AceRizzBinding.count).to eq(0)
    end

    it "clears the Google subject and suggested handle on cancel, discard, purge and switch" do
      start_create(username: "marcus_t")
      link_google
      handoff = RizzClaimHandoff.last
      expect(handoff).to have_attributes(google_uid: uid, suggested_username: "marcus_t")
      post rizz_create_cancel_path
      expect(handoff.reload).to have_attributes(google_uid: nil, suggested_username: nil, email: nil)

      handoff.update!(email: email, google_uid: uid, suggested_username: "marcus_t")
      handoff.discard_draft!
      expect(handoff.reload).to have_attributes(google_uid: nil, suggested_username: nil)

      handoff.update!(email: email, google_uid: uid, suggested_username: "marcus_t", consumed_at: nil, expires_at: 1.second.ago)
      RizzClaimHandoff.purge_spent_drafts!
      expect(handoff.reload).to have_attributes(google_uid: nil, suggested_username: nil, email: nil)

      handoff.update!(intent: "create", email: email, google_uid: uid, suggested_username: "marcus_t")
      handoff.switch_to_claim!
      expect(handoff.reload).to have_attributes(intent: "claim", google_uid: nil, suggested_username: nil)
    end

    it "does not let the Google callback prove a Claim for a Create browser" do
      create(:ace, email: "owner@example.com", google_uid: uid)
      start_create
      link_google(google_email: "owner@example.com")
      get rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(RizzClaimHandoff.last.verified_ace_id).to be_nil
    end
  end

  describe "cookie exclusivity" do
    it "clears the Create cookie when a Claim starts, so the browser never holds both" do
      start_create
      post rizz_claim_start_path, params: { handoff: speaker.claim_handoff(callback_uri: callback_uri, jti: "claim-after-create") }
      expect(set_cookies).to match(/rizz_create_local=;|rizz_create_local=$/m)
      expect(set_cookies).to match(/rizz_claim_local=[^;\s]/)
      get rizz_create_path
      expect(response).to redirect_to(new_ace_session_path)
      get rizz_claim_prove_path
      expect(response).to have_http_status(:ok)
    end

    it "clears the Claim cookie when a Create starts" do
      post rizz_claim_start_path, params: { handoff: speaker.claim_handoff(callback_uri: callback_uri) }
      start_create(jti: "create-after-claim")
      expect(set_cookies).to match(/rizz_claim_local=;|rizz_claim_local=$/m)
      expect(set_cookies).to match(/rizz_create_local=[^;\s]/)
      get rizz_claim_prove_path
      expect(response).to redirect_to(new_ace_session_path)
      get rizz_create_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "an email that already has an Ace" do
    let!(:existing) { create(:ace, email: email, username: "hoops_marcus", google_uid: nil) }

    def expect_claim_proof_without_changes
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(existing.reload).to have_attributes(google_uid: nil, username: "hoops_marcus", confirmed_at: existing.confirmed_at, unconfirmed_email: nil)
      expect(existing.valid_password?("password123")).to be(true)
      expect(AceRizzBinding.count).to eq(0)
      expect(RizzClaimReceipt.count).to eq(0)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "at start continues as a claim handoff, without linking, emailing, or modifying the Ace" do
      expect { start_create }.not_to change(Ace, :count)
      expect_claim_proof_without_changes
      expect(RizzClaimHandoff.last).to have_attributes(intent: "claim", email: nil, verified_ace_id: nil)
      expect(RizzClaimHandoff.last.expires_at).to be_within(5.seconds).of(5.minutes.from_now)
      expect(set_cookies).to match(/rizz_claim_local=/)
      follow_redirect!
      expect(response.body).to include("Confirm with password", "Marcus T. (Rizz)")
      expect(request.env["warden"].user(:ace)).to be_nil

      post rizz_claim_verify_password_path, params: { email: email, password: "password123" }
      expect(response).to redirect_to(rizz_claim_confirm_path)
    end

    it "matches the email regardless of case" do
      start_create(email: "Marcus.Tate@GMAIL.com")
      expect_claim_proof_without_changes
    end

    it "when it appears after the form was shown, switches the handoff to a claim on submit, discarding nothing but the create intent" do
      other_email = "late.arrival@example.com"
      start_create(email: other_email)
      create(:ace, email: other_email)
      expect { submit }.not_to change(Ace, :count)
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(set_cookies).to match(/rizz_claim_local=/)
      expect(RizzClaimHandoff.last).to have_attributes(intent: "claim", email: nil, encrypted_password: nil, consumed_at: nil)
      expect(RizzClaimReceipt.count).to eq(0)
      get rizz_create_path
      expect(response).to redirect_to(new_ace_session_path)
    end

    it "does not let the claim proof be skipped: the switched handoff still needs a fresh proof" do
      other_email = "late.arrival@example.com"
      start_create(email: other_email)
      late = create(:ace, email: other_email)
      submit
      follow_redirect!
      get rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
      post rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(RizzClaimReceipt.count).to eq(0)
      expect(late.reload.active_rizz_binding).to be_nil
    end

    it "keeps returning 409 email_taken on retry when the email is taken after the receipt" do
      other_email = "last.second@example.com"
      start_create(email: other_email)
      submit
      receipt = receipt_from_redirect
      reset!
      late = create(:ace, email: other_email, username: "first_to_arrive")
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("error" => "email_taken")
      expect(Ace.where(email: other_email)).to contain_exactly(late)
      expect(late.reload).to have_attributes(username: "first_to_arrive", google_uid: nil)
      expect(AceRizzBinding.count).to eq(0)
      expect(RizzClaimReceipt.last.consumed_at).to be_nil
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("error" => "email_taken")
    end

    it "answers 409 email_taken when the email index rejects an insert that validation did not see" do
      other_email = "index.race@example.com"
      start_create(email: other_email)
      submit
      receipt = receipt_from_redirect
      reset!
      racing = create(:ace, email: other_email, username: "first_to_arrive")
      allow_any_instance_of(Ace).to receive(:valid?).and_return(true)
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("error" => "email_taken")
      expect(Ace.where(email: other_email)).to contain_exactly(racing)
      expect(AceRizzBinding.count).to eq(0)
    end

    it "when the handle is taken after the receipt, the exchange answers a plain 409 conflict and creates nothing" do
      start_create(email: "new.handle@example.com")
      submit
      receipt = receipt_from_redirect
      reset!
      create(:ace, username: "marcus_tate")
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("error" => "conflict")
      expect(Ace.where(email: "new.handle@example.com")).to be_empty
      expect(AceRizzBinding.count).to eq(0)
    end
  end

  describe "separation from Claim" do
    it "refuses every claim step with a create cookie, and every create step with a claim cookie" do
      start_create
      handoff = RizzClaimHandoff.last
      [ [ :get, rizz_claim_prove_path ], [ :get, rizz_claim_confirm_path ], [ :post, rizz_claim_confirm_path ],
        [ :post, rizz_claim_verify_password_path, { email: "x@example.com", password: "password123" } ] ].each do |verb, path, params|
        public_send(verb, path, params: params)
        expect(response).to redirect_to(new_ace_session_path), "#{verb} #{path}"
      end

      reset!
      post rizz_claim_start_path, params: { handoff: speaker.claim_handoff(callback_uri: callback_uri) }
      get rizz_create_path
      expect(response).to redirect_to(new_ace_session_path)
      submit
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimReceipt.count).to eq(0)
      expect(handoff.reload.consumed_at).to be_nil
    end

    it "does not honor a create handoff's cookie value under the claim cookie name" do
      start_create
      handoff = RizzClaimHandoff.last
      attacker = open_session
      attacker.get rizz_create_path
      attacker.post rizz_create_path, params: onboarding
      attacker.post rizz_create_cancel_path
      expect(redirect_path(attacker)).to eq(new_ace_session_path)
      expect(handoff.reload.consumed_at).to be_nil
    end
  end

  describe "browser binding" do
    it "refuses onboarding without the cookie that started it" do
      start_create
      attacker = open_session
      attacker.get rizz_create_path
      expect(redirect_path(attacker)).to eq(new_ace_session_path)
      attacker.post rizz_create_path, params: onboarding
      expect(redirect_path(attacker)).to eq(new_ace_session_path)
      expect(RizzClaimReceipt.count).to eq(0)
      expect(RizzClaimHandoff.last).to have_attributes(consumed_at: nil, encrypted_password: nil)
    end

    it "does not create an Ace for a handoff replayed in a different browser, because no Speaker receipt can be exchanged" do
      jwt = speaker.create_handoff(callback_uri: callback_uri)
      attacker = open_session
      attacker.post rizz_create_start_path, params: { handoff: jwt }
      attacker.post rizz_create_path, params: onboarding
      attacker_receipt = Rack::Utils.parse_query(URI(attacker.response.location).query).fetch("receipt")
      expect(Ace.where(email: email)).to be_empty
      expect(RizzClaimReceipt.last.ace_id).to be_nil
      expect(attacker_receipt).to be_present
    end

    it "refuses a cookie whose token does not match, an expired handoff, and a spent handoff" do
      start_create
      RizzClaimHandoff.last.update!(browser_token_digest: RizzClaimHandoff.digest("another browser"))
      get rizz_create_path
      expect(response).to redirect_to(new_ace_session_path)

      RizzClaimHandoff.last.update!(browser_token_digest: RizzClaimHandoff.digest(nil))
      reset!
      start_create(jti: "second")
      RizzClaimHandoff.last.update!(expires_at: 1.minute.ago)
      submit
      expect(response).to redirect_to(new_ace_session_path)
      expect(Ace.count).to eq(0)
    end

    it "does not let a spent handoff be submitted twice" do
      start_create
      submit
      expect(response.location).to start_with(callback_uri)
      submit
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimReceipt.count).to eq(1)
    end

    it "lets only one concurrent submission win the handoff" do
      start_create
      handoff = RizzClaimHandoff.last
      expect([ handoff.consume!, RizzClaimHandoff.find(handoff.id).consume! ]).to eq([ true, false ])
    end

    it "cancels without a receipt or an Ace" do
      start_create
      post rizz_create_cancel_path
      expect(response).to redirect_to(root_path)
      expect(RizzClaimHandoff.last).to have_attributes(consumed_at: be_present, email: nil, display_name: nil)
      submit
      expect(RizzClaimReceipt.count).to eq(0)
      expect(Ace.count).to eq(0)
    end
  end

  describe "exchange" do
    def onboarded_receipt
      start_create
      submit
      receipt_from_redirect.tap { reset! }
    end

    it "keeps a create receipt single-use, unexpired, and tied to its operation and client credentials" do
      receipt = onboarded_receipt
      exchange(receipt: receipt, headers: {})
      expect(response).to have_http_status(:unauthorized)
      exchange(receipt: receipt, operation_id: "op-2")
      expect(response).to have_http_status(:bad_request)
      RizzClaimReceipt.last.update!(expires_at: 1.second.ago)
      exchange(receipt: receipt)
      expect(response).to have_http_status(:bad_request)
      expect(Ace.count).to eq(0)
    end

    it "returns 409 and creates no Ace when the Rizz subject is already bound to another Ace" do
      AceRizzBinding.create!(ace: create(:ace), rizz_sub: "pairwise-sub-1", operation_id: "old-op")
      receipt = onboarded_receipt
      expect { exchange(receipt: receipt) }.not_to change(Ace, :count)
      expect(response).to have_http_status(:conflict)
      expect(RizzClaimReceipt.last.consumed_at).to be_nil
    end

    it "reconnects a disconnected binding for the same subject to the new Ace" do
      old = create(:ace)
      AceRizzBinding.create!(ace: old, rizz_sub: "pairwise-sub-1", operation_id: "old-op", rizz_session_epoch: 9, status: "disconnected", disconnected_at: 1.day.ago)
      exchange(receipt: onboarded_receipt, epoch: 4)
      expect(response).to have_http_status(:ok)
      expect(AceRizzBinding.last).to have_attributes(ace_id: Ace.find_by!(email: email).id, status: "active", rizz_session_epoch: 9, operation_id: "op-1")
    end

    it "treats a create receipt whose handoff lost its password as invalid" do
      receipt = onboarded_receipt
      RizzClaimHandoff.last.discard_draft!
      exchange(receipt: receipt)
      expect(response).to have_http_status(:bad_request)
      expect(Ace.where(email: email)).to be_empty
    end
  end

  describe "staged password digests and rollback" do
    it "rolls the whole onboarding back when the receipt cannot be issued, so the retry still works" do
      start_create
      allow(RizzClaimReceipt).to receive(:issue!).and_raise(ActiveRecord::StatementInvalid)
      expect { submit }.to raise_error(ActiveRecord::StatementInvalid)
      expect(RizzClaimHandoff.last).to have_attributes(consumed_at: nil, encrypted_password: nil, username: nil)
      allow(RizzClaimReceipt).to receive(:issue!).and_call_original
      submit
      expect(response.location).to start_with(callback_uri)
    end

    it "rolls the whole exchange back when binding fails after the Ace was saved" do
      start_create
      submit
      receipt = receipt_from_redirect
      reset!
      allow(AceRizzBinding).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(Ace.where(email: email)).to be_empty
      expect(RizzClaimReceipt.last.consumed_at).to be_nil
      expect(RizzClaimHandoff.last.encrypted_password).to be_present
    end

    it "keeps the digest only while the receipt can still be spent, and purges it from spent or abandoned drafts" do
      start_create
      submit
      handoff = RizzClaimHandoff.last
      expect(handoff.encrypted_password).to be_present
      RizzClaimHandoff.purge_spent_drafts!
      expect(handoff.reload.encrypted_password).to be_present

      handoff.update!(consumed_at: (RizzClaimReceipt::LIFETIME + 5.seconds).ago)
      RizzClaimHandoff.purge_spent_drafts!
      expect(handoff.reload).to have_attributes(email: nil, display_name: nil, encrypted_password: nil, username: nil)
    end

    it "clears personal data from expired drafts even if the form was never submitted" do
      start_create
      handoff = RizzClaimHandoff.last
      handoff.update!(expires_at: 1.second.ago)

      RizzClaimHandoff.purge_spent_drafts!

      expect(handoff.reload).to have_attributes(email: nil, display_name: nil, consumed_at: nil)
    end

    it "purges abandoned digests whenever another handoff starts, and the exchange then refuses the stale receipt" do
      start_create
      submit
      receipt = receipt_from_redirect
      reset!
      RizzClaimHandoff.last.update!(consumed_at: 2.minutes.ago)
      RizzClaimReceipt.last.update!(expires_at: 1.minute.from_now)
      start_create(jti: "another")
      expect(RizzClaimHandoff.where.not(encrypted_password: nil)).to be_empty
      exchange(receipt: receipt)
      expect(response).to have_http_status(:bad_request)
      expect(Ace.where(email: email)).to be_empty
    end

    it "is scheduled to run every few minutes in production" do
      recurring = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "rizz_onboarding_digests")
      expect(recurring).to include("command" => "RizzClaimHandoff.purge_spent_drafts!")
    end
  end

  describe "when disabled" do
    it "returns 404 for every create endpoint" do
      with_rizz_env("RIZZ_SIGN_IN_ENABLED" => "0") do
        post rizz_create_start_path_for_disabled, params: { handoff: "x" }
        expect(response).to have_http_status(:not_found)
        get "/auth/rizz/create"
        expect(response).to have_http_status(:not_found)
        post "/auth/rizz/create"
        expect(response).to have_http_status(:not_found)
        post "/auth/rizz/create/cancel"
        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns 404 when the Rizz client secret is missing" do
      with_rizz_env("RIZZ_OIDC_CLIENT_SECRET" => nil) do
        post "/auth/rizz/create/start", params: { handoff: "x" }
        expect(response).to have_http_status(:not_found)
      end
    end

    def rizz_create_start_path_for_disabled = "/auth/rizz/create/start"
  end
end
