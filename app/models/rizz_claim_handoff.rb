# A verified Speaker claim handoff, held server-side while the browser proves
# it controls a local Ace. The browser only carries a token matching
# browser_token_digest.
class RizzClaimHandoff < ApplicationRecord
  PROOF_WINDOW = 5.minutes

  belongs_to :verified_ace, class_name: "Ace", optional: true

  validates :handoff_jti, :operation_id, :speaker_label, :callback_uri, :browser_token_digest, :expires_at, presence: true

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def usable?
    consumed_at.nil? && expires_at.future?
  end

  def proven?
    verified_ace_id.present? && verified_at.present? && verified_at > PROOF_WINDOW.ago
  end

  def prove!(ace)
    update!(verified_ace: ace, verified_at: Time.current)
  end

  # Atomic: only one caller can spend the handoff.
  def consume!
    self.class.where(id: id, consumed_at: nil).update_all(consumed_at: Time.current, updated_at: Time.current) == 1
  end
end
