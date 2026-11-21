require "rails_helper"

RSpec.describe RizzSignIn::Configuration do
  include_context "with a Rizz speaker"

  subject(:configuration) { described_class.new }

  it "is configured and enabled with the flag, issuer and client credentials" do
    expect(configuration).to be_configured
    expect(configuration).to be_enabled
  end

  it "stays configured but not enabled when the flag is off" do
    with_rizz_env("RIZZ_SIGN_IN_ENABLED" => nil) do
      expect(configuration).to be_configured
      expect(configuration).not_to be_enabled
    end
  end

  it "is neither configured nor enabled without an issuer or client credentials" do
    %w[RIZZ_OIDC_ISSUER RIZZ_OIDC_CLIENT_ID RIZZ_OIDC_CLIENT_SECRET].each do |name|
      with_rizz_env(name => nil) do
        expect(configuration).not_to be_configured
        expect(configuration).not_to be_enabled
      end
    end
  end

  describe "#claim_exchange_secret" do
    it "defaults to the OIDC client secret" do
      expect(configuration.claim_exchange_secret).to eq(RizzSpeaker::CLIENT_SECRET)
    end

    it "uses RIZZ_CLAIM_EXCHANGE_SECRET when set" do
      with_rizz_env("RIZZ_CLAIM_EXCHANGE_SECRET" => "dedicated") { expect(configuration.claim_exchange_secret).to eq("dedicated") }
    end

    it "ignores a blank RIZZ_CLAIM_EXCHANGE_SECRET" do
      with_rizz_env("RIZZ_CLAIM_EXCHANGE_SECRET" => "") { expect(configuration.claim_exchange_secret).to eq(RizzSpeaker::CLIENT_SECRET) }
    end
  end

  describe "RizzSignIn.mask_email" do
    it "keeps the first character and a few bullets of the name, plus the domain" do
      expect(RizzSignIn.mask_email("tess@example.com")).to eq("t•••@example.com")
      expect(RizzSignIn.mask_email("ab@example.com")).to eq("a•@example.com")
      expect(RizzSignIn.mask_email("a@example.com")).to eq("a@example.com")
    end
  end
end
