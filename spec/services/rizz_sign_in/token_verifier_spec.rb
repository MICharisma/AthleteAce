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
end
