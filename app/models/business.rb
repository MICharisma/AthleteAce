# A business, foundation, school or similar institution that Figures found,
# own, invest in, endorse, promote or are sponsored by. Separate from
# Organization, which keeps its sports-side meaning.
class Business < ApplicationRecord
  include SeedObservation

  has_many :figure_business_relationships, dependent: :restrict_with_error
  has_many :figures, -> { distinct }, through: :figure_business_relationships

  validates :name, :entity_code, presence: true
  validates :entity_code, uniqueness: true
  validates :founded_year, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
