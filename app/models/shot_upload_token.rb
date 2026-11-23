class ShotUploadToken < ApplicationRecord
  PREFIX = "shot_"

  validates :label, presence: true, length: { maximum: 120 }

  def self.issue!(label:)
    secret = PREFIX + SecureRandom.urlsafe_base64(32)
    [create!(label: label, digest: Digest::SHA256.hexdigest(secret)), secret]
  end

  def self.authenticate(secret)
    return unless secret&.match?(/\Ashot_[A-Za-z0-9_-]{43}\z/)

    find_by(digest: Digest::SHA256.hexdigest(secret), revoked_at: nil)
  end
end
