require "rails_helper"

RSpec.describe "Rizz claim", type: :request do
  include_context "with a Rizz speaker"

  let!(:ace) { create(:ace, username: "courtside_tess", email: "tess@example.com", google_uid: "google-uid-1") }
  let(:callback_uri) { "#{RizzSpeaker::ISSUER}/claims/op-1/return" }

  def start_claim(**overrides)
    post rizz_claim_start_path, params: { handoff: speaker.claim_handoff(callback_uri: callback_uri, **overrides) }
  end

  def prove_with_password(account = ace, password: "password123")
    post rizz_claim_verify_password_path, params: { email: account.email, password: password }
  end

  # Runs the claim-only Google OmniAuth round trip with a mocked Google response.
  def prove_with_google(uid: "google-uid-1", email: "tess@example.com", iat: Time.now.to_i, id_sub: uid, provider: "rizz_claim_google")
    info = { sub: id_sub, iat: iat }.compact
    OmniAuth.config.mock_auth[:rizz_claim_google] = OmniAuth::AuthHash.new(provider: provider, uid: uid,
      info: { email: email, email_verified: true, name: "Tess" }, extra: { id_info: info })
    post "/auth/rizz/claim/google"
    expect(response).to redirect_to("http://www.example.com/auth/rizz/claim/google/callback")
    follow_redirect!
  end

  around do |example|
    previous = [ OmniAuth.config.test_mode, OmniAuth.config.mock_auth[:rizz_claim_google] ]
    OmniAuth.config.test_mode = true
    example.run
  ensure
    OmniAuth.config.test_mode, OmniAuth.config.mock_auth[:rizz_claim_google] = previous
  end

  before { allow(Rails.application.config.x.google_oauth).to receive(:enabled).and_return(true) }

  describe "start" do
    it "verifies the handoff, stores it server-side, and sets an encrypted HttpOnly browser cookie" do
      start_claim
      expect(response).to redirect_to(rizz_claim_prove_path)
      handoff = RizzClaimHandoff.last
      expect(handoff).to have_attributes(operation_id: "op-1", speaker_label: "Marcus T. (Rizz)", callback_uri: callback_uri, verified_ace_id: nil, consumed_at: nil)
      cookie = response.headers["set-cookie"]
      expect(cookie).to match(/rizz_claim_local=/)
      expect(cookie).to match(/httponly/i)
      expect(cookie).not_to include(handoff.id)
      expect(handoff.browser_token_digest).to match(/\A\h{64}\z/)
    end

    it "uses a __Host- cookie under HTTPS" do
      https!
      start_claim
      cookie = response.headers["set-cookie"]
      expect(cookie).to match(/__Host-rizz_claim_local=/)
      expect(cookie).to match(/secure/i)
      expect(cookie).to match(/path=\//i)
      expect(cookie).not_to match(/domain=/i)
    end

    it "is POST-only: a GET (even with a valid handoff) is not routed and stores nothing" do
      get "/auth/rizz/claim/start", params: { handoff: speaker.claim_handoff(callback_uri: callback_uri) }
      expect(response).to have_http_status(:not_found)
      expect(RizzClaimHandoff.count).to eq(0)
    end

    it "refuses a replayed handoff jti" do
      jwt = speaker.claim_handoff(callback_uri: callback_uri, jti: "one-use")
      post rizz_claim_start_path, params: { handoff: jwt }
      expect(response).to redirect_to(rizz_claim_prove_path)
      reset!
      post rizz_claim_start_path, params: { handoff: jwt }
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimHandoff.count).to eq(1)
    end

    {
      "a bad signature" => { signing_key: OpenSSL::PKey::EC.generate("prime256v1") },
      "an expired handoff" => { iat: 2.hours.ago.to_i, exp: 1.hour.ago.to_i },
      "another audience" => { aud: "other-client" },
      "another issuer" => { iss: "https://evil.example" },
      "the wrong typ" => { typ: "JWT" },
      "a callback on another origin" => { callback_uri: "https://evil.example/claims/op-1/return" },
      "a callback with a different port" => { callback_uri: "https://rizz.test:8443/claims/op-1/return" },
      "a plain http callback" => { callback_uri: "http://rizz.test/claims/op-1/return" },
      "a callback with credentials" => { callback_uri: "https://user:pass@rizz.test/claims/op-1/return" },
      "no speaker label" => { speaker_label: "" },
      "an overlong speaker label" => { speaker_label: "M" * 121 }
    }.each do |description, overrides|
      it "rejects #{description}" do
        overrides = overrides.dup
        typ = overrides.delete(:typ)
        token = typ ? speaker.sign(speaker.base_claims({ "jti" => "j", "operation_id" => "op-1", "speaker_label" => "Marcus", "callback_uri" => callback_uri }), typ: typ) :
          speaker.claim_handoff(**{ callback_uri: callback_uri }.merge(overrides))
        post rizz_claim_start_path, params: { handoff: token }
        expect(response).to redirect_to(new_ace_session_path)
        expect(RizzClaimHandoff.count).to eq(0)
      end
    end

    it "rejects a missing handoff" do
      post rizz_claim_start_path
      expect(response).to redirect_to(new_ace_session_path)
    end
  end

  describe "browser binding (phishing resistance)" do
    it "refuses every claim step without the browser cookie that started it" do
      start_claim
      handoff = RizzClaimHandoff.last
      attacker = open_session
      [ [ :get, rizz_claim_prove_path ], [ :get, rizz_claim_confirm_path ], [ :post, rizz_claim_confirm_path ],
        [ :post, rizz_claim_verify_password_path, { email: ace.email, password: "password123" } ], [ :post, rizz_claim_cancel_path ] ].each do |verb, path, params|
        attacker.public_send(verb, path, params: params)
        expect([ attacker.response.status, URI(attacker.response.location).path ]).to eq([ 303, new_ace_session_path ]), "#{verb} #{path}"
      end
      expect(handoff.reload).to have_attributes(verified_ace_id: nil, consumed_at: nil)
      expect(RizzClaimReceipt.count).to eq(0)
    end

    it "refuses a cookie whose token does not match the stored digest" do
      start_claim
      RizzClaimHandoff.last.update!(browser_token_digest: RizzClaimHandoff.digest("a different browser's token"))
      get rizz_claim_prove_path
      expect(response).to redirect_to(new_ace_session_path)
    end

    it "refuses an expired or consumed handoff" do
      start_claim
      RizzClaimHandoff.last.update!(expires_at: 1.minute.ago)
      get rizz_claim_prove_path
      expect(response).to redirect_to(new_ace_session_path)
    end
  end

  describe "proof" do
    before { start_claim }

    it "shows password and Google proof, naming the requesting Speaker" do
      get rizz_claim_prove_path
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("form[action='#{rizz_claim_verify_password_path}'] input[type=password]")).to be_present
      expect(page.at_css("form[action='/auth/rizz/claim/google']")).to be_present
      expect(response.body).to include("Marcus T. (Rizz)")
    end

    it "hides Google proof when Google sign-in is not configured" do
      allow(Rails.application.config.x.google_oauth).to receive(:enabled).and_return(false)
      get rizz_claim_prove_path
      expect(response.body).not_to include("Confirm with Google")
    end

    it "accepts the password, then shows both the verified Ace and the Speaker for confirmation" do
      prove_with_password
      expect(response).to redirect_to(rizz_claim_confirm_path)
      expect(RizzClaimHandoff.last).to have_attributes(verified_ace_id: ace.id)
      follow_redirect!
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("dl").text).to include("@courtside_tess", "t•••@example.com", "Marcus T. (Rizz)")
      expect(response.body).not_to include("tess@example.com")
      confirm_form = page.at_css("form[action='#{rizz_claim_confirm_path}']")
      expect(confirm_form["data-turbo"]).to eq("false")
      expect(confirm_form.at_css("input[type=submit], button").text).to include("Connect this account")
      expect(page.at_css("form[action='#{rizz_claim_cancel_path}']").text).to include("Cancel")
    end

    it "rejects a wrong password, an unknown email, and a suspended or unconfirmed Ace without revealing which" do
      prove_with_password(password: "wrong")
      expect(flash[:alert]).to eq("That email and password didn't match.")
      post rizz_claim_verify_password_path, params: { email: "nobody@example.com", password: "password123" }
      expect(flash[:alert]).to eq("That email and password didn't match.")
      ace.update!(suspended_at: Time.current)
      prove_with_password
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(flash[:alert]).to eq("That email and password didn't match.")
      ace.update!(suspended_at: nil, confirmed_at: nil)
      prove_with_password
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(flash[:alert]).to eq("That email and password didn't match.")
      expect(RizzClaimHandoff.last.verified_ace_id).to be_nil
    end

    it "gives a wrong password and a suspended or unconfirmed Ace the identical response" do
      prove_with_password(password: "wrong")
      wrong = [ response.status, response.location, flash[:alert] ]
      [ { suspended_at: Time.current }, { confirmed_at: nil } ].each do |state|
        ace.update!(suspended_at: nil, confirmed_at: Time.current)
        ace.update!(state)
        prove_with_password
        expect([ response.status, response.location, flash[:alert] ]).to eq(wrong)
      end
    end

    it "does not let confirmation be reached before proof" do
      get rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
      post rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(RizzClaimReceipt.count).to eq(0)
    end

    it "requires fresh proof even when the browser is already signed in" do
      sign_in ace
      get rizz_claim_prove_path
      expect(response.body).to include("This browser is signed in as @courtside_tess")
      get rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
      post rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
      expect(RizzClaimReceipt.count).to eq(0)
      prove_with_password
      expect(response).to redirect_to(rizz_claim_confirm_path)
    end

    it "requires the proof to be recent" do
      prove_with_password
      RizzClaimHandoff.last.update!(verified_at: 6.minutes.ago)
      get rizz_claim_confirm_path
      expect(response).to redirect_to(rizz_claim_prove_path)
    end

    it "does not sign the browser in" do
      prove_with_password
      expect(request.env["warden"].user(:ace)).to be_nil
    end

    context "with claim-only Google" do
      it "starts Google with an account chooser that the request cannot override" do
        OmniAuth.config.test_mode = false
        post "/auth/rizz/claim/google", params: { prompt: "none" }
        query = Rack::Utils.parse_query(URI(response.location).query)
        expect(response.location).to start_with("https://accounts.google.com/")
        expect(query).to include("prompt" => "select_account", "access_type" => "online")
        expect(query["scope"].split).to include("openid", "email", "profile")
        expect(query["redirect_uri"]).to eq("http://www.example.com/auth/rizz/claim/google/callback")
      end

      it "does not intercept its paths while Sign in with Rizz is off or Google sign-in is not configured" do
        OmniAuth.config.test_mode = false
        with_rizz_env("RIZZ_SIGN_IN_ENABLED" => nil) do
          post "/auth/rizz/claim/google"
          expect(response).to have_http_status(:not_found)
          expect(response.location).to be_nil
        end
        allow(Rails.application.config.x.google_oauth).to receive(:enabled).and_return(false)
        post "/auth/rizz/claim/google"
        expect(response).to have_http_status(:not_found)
        expect(response.location).to be_nil
      end

      it "accepts a Google identity already linked to an Ace with a fresh iat and matching sub" do
        middleware = Rails.application.config.middleware.find { it.klass == OmniAuth::Strategies::RizzClaimGoogle }
        expect(middleware.args.last[:name]).to eq("rizz_claim_google")

        prove_with_google
        expect(response).to redirect_to(rizz_claim_confirm_path)
        expect(RizzClaimHandoff.last.verified_ace_id).to eq(ace.id)
        expect(request.env["warden"].user(:ace)).to be_nil
      end

      it "accepts a Symbol provider in omniauth.auth as well as a String" do
        prove_with_google(provider: :rizz_claim_google)
        expect(response).to redirect_to(rizz_claim_confirm_path)
        expect(RizzClaimHandoff.last.verified_ace_id).to eq(ace.id)
      end

      it "never goes through Ace.from_google, links by email, or creates an Ace" do
        expect(Ace).not_to receive(:from_google)
        by_email = create(:ace, email: "tess.moreno@gmail.com", google_uid: nil)
        expect { prove_with_google(uid: "never-linked", email: "tess.moreno@gmail.com") }.not_to change(Ace, :count)
        expect(response).to redirect_to(rizz_claim_prove_path)
        expect(by_email.reload.google_uid).to be_nil
        expect(RizzClaimHandoff.last.verified_ace_id).to be_nil
        expect { prove_with_google(uid: "brand-new", email: "new@example.com") }.not_to change(Ace, :count)
        expect(response).to redirect_to(rizz_claim_prove_path)
      end

      it "rejects a stale, missing, non-numeric, or future iat, or a mismatched id_token sub" do
        [ 10.minutes.ago.to_i, nil, "yesterday", 1.hour.from_now.to_i ].each do |iat|
          prove_with_google(iat: iat)
          expect(response).to redirect_to(rizz_claim_prove_path)
          expect(RizzClaimHandoff.last.verified_ace_id).to be_nil
        end

        prove_with_google(uid: "google-uid-1", id_sub: "other-google-uid")
        expect(response).to redirect_to(rizz_claim_prove_path)
        expect(RizzClaimHandoff.last.verified_ace_id).to be_nil
      end

      it "rejects a different provider's identity and a suspended Ace" do
        prove_with_google(provider: "google_oauth2")
        expect(response).to redirect_to(rizz_claim_prove_path)
        ace.update!(suspended_at: Time.current)
        prove_with_google
        expect(response).to redirect_to(rizz_claim_prove_path)
        expect(RizzClaimHandoff.last.verified_ace_id).to be_nil
      end

      it "keeps the Claim proof intact for a Create browser steered to it by an already-linked Google account" do
        post rizz_create_start_path, params: { handoff: speaker.create_handoff(callback_uri: callback_uri, email: "new.fan@example.com") }
        expect(Array(response.headers["set-cookie"]).join).to match(/rizz_create_local=/)
        expect { prove_with_google(email: "new.fan@example.com") }.not_to change(Ace, :count)
        expect(response).to redirect_to(rizz_claim_prove_path)
        expect(RizzClaimHandoff.last).to have_attributes(intent: "claim", email: nil, google_uid: nil)

        prove_with_google
        expect(response).to redirect_to(rizz_claim_confirm_path)
        expect(RizzClaimHandoff.last.verified_ace).to eq(ace)
      end

      it "clears a Create cookie when the claim starts" do
        post rizz_create_start_path, params: { handoff: speaker.create_handoff(callback_uri: callback_uri, email: "new.fan@example.com") }
        start_claim(jti: "claim-after-create")
        expect(Array(response.headers["set-cookie"]).join("\n")).to match(/rizz_create_local=;/)
        get rizz_create_path
        expect(response).to redirect_to(new_ace_session_path)
      end

      it "returns to the proof page when Google is cancelled" do
        OmniAuth.config.mock_auth[:rizz_claim_google] = :access_denied
        post "/auth/rizz/claim/google"
        follow_redirect!
        expect(response).to redirect_to(rizz_claim_prove_path)
      end

      it "refuses the claim callback without the browser cookie" do
        reset!
        OmniAuth.config.mock_auth[:rizz_claim_google] = OmniAuth::AuthHash.new(provider: "rizz_claim_google", uid: "google-uid-1", extra: { id_info: { sub: "google-uid-1", iat: Time.now.to_i } })
        ace
        post "/auth/rizz/claim/google"
        follow_redirect!
        expect(response).to redirect_to(new_ace_session_path)
      end

      it "keeps Devise's normal Google callback independent of claims" do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "google-uid-1",
          info: { email: ace.email, email_verified: true, name: "Tess" })
        post ace_google_oauth2_omniauth_authorize_path
        follow_redirect!
        expect(request.env["warden"].user(:ace)).to eq(ace)
        expect(RizzClaimHandoff.last.verified_ace_id).to be_nil
      end
    end
  end

  describe "confirm and exchange" do
    def claim_and_confirm
      start_claim
      prove_with_password
      post rizz_claim_confirm_path
    end

    def exchange(operation_id: "op-1", receipt:, rizz_sub: "pairwise-sub-1", epoch: 3, headers: rizz_basic_auth)
      post "/auth/rizz/claim/exchange", params: { operation_id: operation_id, receipt: receipt, rizz_sub: rizz_sub, rizz_session_epoch: epoch }.to_json,
        headers: headers.merge("Content-Type" => "application/json")
    end

    def receipt_from_redirect
      Rack::Utils.parse_query(URI(response.location).query).fetch("receipt")
    end

    it "mints a single-use 60 second receipt and returns to the Speaker callback" do
      claim_and_confirm
      uri = URI(response.location)
      query = Rack::Utils.parse_query(uri.query)
      expect("#{uri.scheme}://#{uri.host}#{uri.path}").to eq(callback_uri)
      expect(query["operation_id"]).to eq("op-1")
      expect(query["receipt"]).to be_present
      stored = RizzClaimReceipt.last
      expect(stored.receipt_digest).to eq(Digest::SHA256.hexdigest(query["receipt"]))
      expect(stored.receipt_digest).not_to eq(query["receipt"])
      expect(stored.expires_at).to be_within(5.seconds).of(60.seconds.from_now)
      expect(stored).to have_attributes(ace_id: ace.id, operation_id: "op-1", consumed_at: nil)
      expect(RizzClaimHandoff.last.consumed_at).to be_present
      expect(response.headers["set-cookie"]).to match(/rizz_claim_local=;|rizz_claim_local=$/)
    end

    it "does not let the handoff be confirmed twice" do
      claim_and_confirm
      post rizz_claim_confirm_path
      expect(response).to redirect_to(new_ace_session_path)
      expect(RizzClaimReceipt.count).to eq(1)
    end

    it "cancels without minting a receipt" do
      start_claim
      prove_with_password
      post rizz_claim_cancel_path
      expect(response).to redirect_to(root_path)
      expect(RizzClaimHandoff.last.consumed_at).to be_present
      post rizz_claim_confirm_path
      expect(RizzClaimReceipt.count).to eq(0)
    end

    it "lets ClaimExchange decide, so an Ace still bound to the same subject can re-claim" do
      AceRizzBinding.create!(ace: ace, rizz_sub: "pairwise-sub-1", operation_id: "old-op", rizz_session_epoch: 4)
      claim_and_confirm
      expect(response).to have_http_status(:see_other)
      expect(response.location).to start_with(callback_uri)
      receipt = receipt_from_redirect
      reset!
      exchange(receipt: receipt, epoch: 5)
      expect(response).to have_http_status(:ok)
      expect(AceRizzBinding.where(ace: ace).count).to eq(1)
      expect(AceRizzBinding.last).to have_attributes(rizz_sub: "pairwise-sub-1", operation_id: "op-1", status: "active", rizz_session_epoch: 5)
    end

    it "still mints a receipt for an Ace bound to a different subject, which the exchange then refuses with 409" do
      AceRizzBinding.create!(ace: ace, rizz_sub: "someone-else", operation_id: "old-op")
      claim_and_confirm
      receipt = receipt_from_redirect
      reset!
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(AceRizzBinding.where(ace: ace).pluck(:rizz_sub)).to eq([ "someone-else" ])
    end

    it "binds the Ace when the Speaker exchanges the receipt, idempotently" do
      claim_and_confirm
      receipt = receipt_from_redirect
      reset!
      exchange(receipt: receipt)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("ok" => true, "local_handle" => "@courtside_tess", "has_independent_recovery" => true)
      binding = AceRizzBinding.last
      expect(binding).to have_attributes(ace_id: ace.id, rizz_sub: "pairwise-sub-1", rizz_session_epoch: 3, operation_id: "op-1", status: "active")
      expect(binding.connected_at).to be_present
      expect(RizzClaimReceipt.last.consumed_at).to be_present

      exchange(receipt: receipt)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["local_handle"]).to eq("@courtside_tess")
      expect(AceRizzBinding.count).to eq(1)
    end

    it "falls back to a masked email, never the raw address, when the Ace has no handle" do
      noname = create(:ace, :without_identity, email: "noname@example.com")
      receipt = RizzClaimReceipt.issue!(ace: noname, operation_id: "op-9")
      exchange(operation_id: "op-9", receipt: receipt)
      expect(response.parsed_body["local_handle"]).to eq("n•••@example.com")
      expect(response.body).not_to include("noname@example.com")
    end

    it "marks every exchange response uncacheable, including rejections" do
      exchange(receipt: "made-up")
      expect(response.headers["Cache-Control"]).to include("no-store")
      exchange(receipt: "made-up", headers: {})
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "accepts a dedicated RIZZ_CLAIM_EXCHANGE_SECRET instead of the OIDC client secret when one is set" do
      receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      with_rizz_env("RIZZ_CLAIM_EXCHANGE_SECRET" => "dedicated-exchange-secret") do
        exchange(receipt: receipt, headers: rizz_basic_auth)
        expect(response).to have_http_status(:unauthorized)
        exchange(receipt: receipt, headers: rizz_basic_auth(secret: "dedicated-exchange-secret"))
        expect(response).to have_http_status(:ok)
      end
    end

    it "requires the client credentials" do
      receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      [ {}, rizz_basic_auth(secret: "wrong"), rizz_basic_auth(id: "wrong") ].each do |headers|
        exchange(receipt: receipt, headers: headers)
        expect(response).to have_http_status(:unauthorized)
      end
      expect(AceRizzBinding.count).to eq(0)
      expect(RizzClaimReceipt.last.consumed_at).to be_nil
    end

    it "rejects unknown, expired, spent, and mismatched receipts" do
      exchange(receipt: "made-up")
      expect(response).to have_http_status(:bad_request)
      expired = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      RizzClaimReceipt.last.update!(expires_at: 1.second.ago)
      exchange(receipt: expired)
      expect(response).to have_http_status(:bad_request)
      fresh = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-2")
      exchange(operation_id: "op-1", receipt: fresh)
      expect(response).to have_http_status(:bad_request)
      expect(AceRizzBinding.count).to eq(0)
    end

    it "rejects malformed requests" do
      exchange(receipt: "x", epoch: "nope")
      expect(response).to have_http_status(:bad_request)
      exchange(receipt: "x", rizz_sub: "")
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 409 when the Ace is already actively bound to another Rizz subject" do
      AceRizzBinding.create!(ace: ace, rizz_sub: "someone-else", operation_id: "old-op")
      receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("error" => "conflict")
      expect(AceRizzBinding.where(ace: ace).pluck(:rizz_sub)).to eq([ "someone-else" ])
      expect(RizzClaimReceipt.last.consumed_at).to be_nil
    end

    it "returns 409 when the Rizz subject is already actively bound to another Ace, without saying which" do
      other = create(:ace)
      AceRizzBinding.create!(ace: other, rizz_sub: "pairwise-sub-1", operation_id: "old-op")
      receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      exchange(receipt: receipt)
      expect(response).to have_http_status(:conflict)
      expect(response.body).not_to include(other.email, other.id)
      expect(AceRizzBinding.find_by(rizz_sub: "pairwise-sub-1").ace_id).to eq(other.id)
    end

    it "returns 409 when an operation_id was already used for a different subject" do
      claim_and_confirm
      receipt = receipt_from_redirect
      exchange(receipt: receipt)
      other_receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      exchange(receipt: other_receipt, rizz_sub: "a-different-sub")
      expect(response).to have_http_status(:conflict)
    end

    it "reconnects a disconnected binding for the same subject with the new operation and no lower epoch" do
      AceRizzBinding.create!(ace: ace, rizz_sub: "pairwise-sub-1", operation_id: "old-op", rizz_session_epoch: 9, status: "disconnected", disconnected_at: 1.day.ago)
      receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      exchange(receipt: receipt, epoch: 4)
      expect(response).to have_http_status(:ok)
      expect(AceRizzBinding.count).to eq(1)
      expect(AceRizzBinding.last).to have_attributes(status: "active", operation_id: "op-1", rizz_session_epoch: 9, disconnected_at: nil)
    end

    it "lets only one concurrent exchange spend a receipt" do
      receipt = RizzClaimReceipt.issue!(ace: ace, operation_id: "op-1")
      stored = RizzClaimReceipt.find_by_receipt(receipt)
      expect([ stored.consume!, RizzClaimReceipt.find(stored.id).consume! ]).to eq([ true, false ])
    end
  end

  describe "when disabled" do
    it "returns 404 for every claim endpoint, but keeps back-channel logout mounted" do
      with_rizz_env("RIZZ_SIGN_IN_ENABLED" => "0") do
        post "/auth/rizz/claim/start", params: { handoff: "x" }
        expect(response).to have_http_status(:not_found)
        post "/auth/rizz/claim/exchange"
        expect(response).to have_http_status(:not_found)
        post "/auth/rizz/backchannel_logout"
        expect(response).to have_http_status(:bad_request)
      end
    end

    it "returns 404 for back-channel logout only when Rizz is not configured at all" do
      with_rizz_env("RIZZ_OIDC_CLIENT_SECRET" => nil) do
        post "/auth/rizz/backchannel_logout"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
