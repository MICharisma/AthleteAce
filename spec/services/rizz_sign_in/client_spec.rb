require "rails_helper"

RSpec.describe RizzSignIn::Client do
  include_context "with a Rizz speaker"

  describe ".exchange_code" do
    it "form-encodes the client credentials before HTTP Basic encoding (RFC 6749 section 2.3.1)" do
      captured = nil
      allow(RizzSignIn::HttpClient).to receive(:post_form) do |_url, _params, basic_auth:|
        captured = basic_auth
        { "token_type" => "Bearer", "id_token" => "the.id.token" }
      end

      with_rizz_env("RIZZ_OIDC_CLIENT_ID" => "client+id%1", "RIZZ_OIDC_CLIENT_SECRET" => "se+cr%et& /x") do
        expect(described_class.exchange_code(code: "c", code_verifier: "v", redirect_uri: "https://app.test/cb")).to eq("the.id.token")
      end

      expect(captured).to eq([ "client%2Bid%251", "se%2Bcr%25et%26+%2Fx" ])
      expect(captured.map { URI.decode_www_form_component(it) }).to eq([ "client+id%1", "se+cr%et& /x" ])
    end

    it "leaves ordinary credentials unchanged" do
      captured = nil
      allow(RizzSignIn::HttpClient).to receive(:post_form) do |_url, _params, basic_auth:|
        captured = basic_auth
        { "token_type" => "Bearer", "id_token" => "x.y.z" }
      end
      described_class.exchange_code(code: "c", code_verifier: "v", redirect_uri: "https://app.test/cb")
      expect(captured).to eq([ RizzSpeaker::CLIENT_ID, RizzSpeaker::CLIENT_SECRET ])
    end
  end
end
