require "rails_helper"

RSpec.describe RizzSignIn::TokenVerifier do
  include_context "with a Rizz speaker"

  let(:now) { Time.now.to_i }

  def id_token_with(**overrides)
    speaker.id_token(nonce: "n", epoch: 2, **overrides)
  end

  describe "iat clock skew" do
    it "accepts an iat slightly in the future, within LEEWAY" do
      claims = described_class.verify_id_token(id_token_with(iat: now + 5, exp: now + 305), nonce: "n")
      expect(claims["sub"]).to eq("pairwise-sub-1")
    end

    it "accepts an iat right at the edge of LEEWAY" do
      expect { described_class.verify_id_token(id_token_with(iat: now + described_class::LEEWAY - 2, exp: now + 300), nonce: "n") }.not_to raise_error
    end

    it "rejects an iat beyond LEEWAY" do
      expect { described_class.verify_id_token(id_token_with(iat: now + 60, exp: now + 360), nonce: "n") }.to raise_error(RizzSignIn::InvalidToken)
    end

    it "applies to logout tokens and claim handoffs too" do
      expect { described_class.verify_logout_token(speaker.logout_token(iat: now + 5, exp: now + 305)) }.not_to raise_error
      expect { described_class.verify_logout_token(speaker.logout_token(iat: now + 60, exp: now + 360)) }.to raise_error(RizzSignIn::InvalidToken)
      expect { described_class.verify_claim_handoff(speaker.claim_handoff(iat: now + 5, exp: now + 305)) }.not_to raise_error
      expect { described_class.verify_claim_handoff(speaker.claim_handoff(iat: now + 60, exp: now + 360)) }.to raise_error(RizzSignIn::InvalidToken)
    end
  end

  describe ".verify_create_handoff" do
    it "returns the claims with the email normalized and the display name trimmed" do
      claims = described_class.verify_create_handoff(speaker.create_handoff(email: " Marcus.Tate@Gmail.com ", display_name: " Marcus Tate "))
      expect(claims).to include("email" => "marcus.tate@gmail.com", "display_name" => "Marcus Tate", "operation_id" => "op-1")
    end

    it "accepts an empty suggested display name" do
      expect(described_class.verify_create_handoff(speaker.create_handoff(display_name: ""))["display_name"]).to eq("")
    end

    it "accepts exactly five minutes and rejects longer, since a create handoff expires in five minutes" do
      expect { described_class.verify_create_handoff(speaker.create_handoff(iat: now, exp: now + 300)) }.not_to raise_error
      expect { described_class.verify_create_handoff(speaker.create_handoff(iat: now, exp: now + 301)) }.to raise_error(RizzSignIn::InvalidToken)
      expect { described_class.verify_claim_handoff(speaker.claim_handoff(iat: now, exp: now + 600)) }.not_to raise_error
    end

    it "is not interchangeable with a claim handoff" do
      expect { described_class.verify_create_handoff(speaker.claim_handoff) }.to raise_error(RizzSignIn::InvalidToken)
      expect { described_class.verify_claim_handoff(speaker.create_handoff) }.to raise_error(RizzSignIn::InvalidToken)
    end

    it "rejects a missing or malformed email and a missing, non-string or overlong display name" do
      [ { email: nil }, { email: "" }, { email: 5 }, { email: "no-at-sign" }, { email: "a b@example.com" }, { email: "#{"a" * 250}@example.com" } ].each do |overrides|
        expect { described_class.verify_create_handoff(speaker.create_handoff(**overrides)) }.to raise_error(RizzSignIn::InvalidToken), overrides.inspect
      end
      [ { display_name: nil }, { display_name: 7 }, { display_name: "M" * 61 } ].each do |overrides|
        expect { described_class.verify_create_handoff(speaker.create_handoff(**overrides)) }.to raise_error(RizzSignIn::InvalidToken), overrides.inspect
      end
    end
  end
end
