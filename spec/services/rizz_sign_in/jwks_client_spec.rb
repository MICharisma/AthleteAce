require "rails_helper"

RSpec.describe RizzSignIn::JwksClient do
  include ActiveSupport::Testing::TimeHelpers
  include_context "with a Rizz speaker"

  it "caches discovery and keys" do
    2.times { described_class.discovery; described_class.key_for("speaker-1") }
    expect(speaker.fetches).to eq(%w[https://rizz.test/.well-known/openid-configuration https://rizz.test/.well-known/jwks.json])
  end

  it "refreshes once for an unknown kid and picks up rotated keys" do
    described_class.key_for("speaker-1")
    speaker.rotate!
    travel 31.seconds do
      expect(described_class.key_for("speaker-2")).to be_a(OpenSSL::PKey::EC)
      expect(described_class.key_for("speaker-1")).to be_a(OpenSSL::PKey::EC)
    end
  end

  it "rate-limits refreshes triggered by unknown kids" do
    described_class.key_for("speaker-1")
    before = speaker.fetches.size
    3.times { expect(described_class.key_for("attacker-kid")).to be_nil }
    expect(speaker.fetches.size - before).to be <= 1
    travel 31.seconds do
      described_class.key_for("another-kid")
      expect(speaker.fetches.size - before).to be <= 2
    end
  end

  it "lets only one of many concurrent unknown-kid lookups refresh" do
    described_class.key_for("speaker-1")
    before = speaker.fetches.size
    allow(speaker).to receive(:jwks).and_wrap_original { |original| sleep 0.05; original.call }
    travel 31.seconds do
      threads = 8.times.map { Thread.new { described_class.key_for("attacker-kid") } }
      expect(threads.map(&:value)).to all(be_nil)
    end
    expect(speaker.fetches.size - before).to eq(1)
  end

  it "keeps serving cached keys when a refresh fails" do
    described_class.key_for("speaker-1")
    allow(RizzSignIn::HttpClient).to receive(:get_json).and_raise(RizzSignIn::Unavailable)
    travel 2.hours do
      expect(described_class.key_for("speaker-1")).to be_a(OpenSSL::PKey::EC)
    end
  end

  it "raises when the issuer cannot be reached and nothing is cached" do
    allow(RizzSignIn::HttpClient).to receive(:get_json).and_raise(RizzSignIn::Unavailable)
    expect { described_class.key_for("speaker-1") }.to raise_error(RizzSignIn::Unavailable)
  end

  it "ignores keys that are not ES256 P-256 signing keys" do
    jwks = speaker.jwks
    jwks["keys"] << jwks["keys"].first.merge("kid" => "enc", "use" => "enc") << jwks["keys"].first.merge("kid" => "rs", "alg" => "RS256") <<
      jwks["keys"].first.merge("kid" => "p384", "crv" => "P-384")
    allow(speaker).to receive(:jwks).and_return(jwks)
    expect(%w[enc rs p384].map { described_class.key_for(it) }).to all(be_nil)
  end

  it "rejects a discovery document for another issuer or with endpoints elsewhere" do
    document = speaker.discovery.merge("issuer" => "https://other.test")
    allow(speaker).to receive(:discovery).and_return(document)
    expect { described_class.discovery }.to raise_error(RizzSignIn::Unavailable)
    RizzSignIn::JwksClient.reset!
    allow(speaker).to receive(:discovery).and_return(speaker.discovery.merge("jwks_uri" => "https://evil.example/jwks.json"))
    expect { described_class.discovery }.to raise_error(RizzSignIn::Unavailable)
  end
end
