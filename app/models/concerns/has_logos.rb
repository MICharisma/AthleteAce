module HasLogos
  extend ActiveSupport::Concern

  included do
    has_many :logos, as: :owner, dependent: :destroy
    has_many :current_logos, -> { where(ongoing: true).order(:entity_code) }, as: :owner, class_name: "Logo"
    belongs_to :primary_logo, class_name: "Logo", optional: true
    validate :primary_logo_matches_owner
  end

  def display_logo_image
    primary_logo&.image || current_logos.filter_map(&:image).min_by { |image| image.content_type == "image/svg+xml" ? 1 : 0 }
  end

  private

  def primary_logo_matches_owner
    errors.add :primary_logo, "must belong to this #{model_name.human.downcase}" if primary_logo && primary_logo.owner != self
  end
end
