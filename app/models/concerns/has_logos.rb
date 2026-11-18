module HasLogos
  extend ActiveSupport::Concern

  included do
    has_many :logos, as: :owner, dependent: :destroy
    belongs_to :primary_logo, class_name: "Logo", optional: true
    validate :primary_logo_matches_owner
  end

  private

  def primary_logo_matches_owner
    errors.add :primary_logo, "must belong to this #{model_name.human.downcase}" if primary_logo && primary_logo.owner != self
  end
end
