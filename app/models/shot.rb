class Shot < ApplicationRecord
  IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif image/avif].freeze

  has_one_attached :image
  has_many :captures, dependent: :destroy
  has_many :players, through: :captures

  normalizes :tags, with: ->(tags) { tags.map { |tag| tag.strip.downcase }.compact_blank.uniq }
  scope :tagged, ->(tag) { where("shots.tags @> ARRAY[?]::text[]", tag.strip.downcase) }
  scope :untagged_players, -> { where.missing(:captures) }

  validate :image_source
  validate :image_type, if: -> { image.attached? }

  def url
    return external_url if external_url.present?
    return unless image.attached?

    Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
  end

  private

  def image_source
    errors.add :image, :blank unless image.attached? || external_url.present?
  end

  def image_type
    errors.add :image, :invalid unless IMAGE_TYPES.include?(image.blob.content_type)
  end
end
