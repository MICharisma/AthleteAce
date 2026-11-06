class Person < ApplicationRecord
  include SeedObservation

  UNNAMED = "Unnamed athlete".freeze

  belongs_to :player, optional: true, inverse_of: :person
  has_many :staff_tenures, dependent: :restrict_with_error

  validates :name, :entity_code, presence: true
  validates :entity_code, uniqueness: true
  validates :player_id, uniqueness: true, allow_nil: true

  # Structured parts set the display name; a person known only by `name` keeps it.
  def first_name=(value)
    super
    self.name = name_from_parts
  end

  def last_name=(value)
    super
    self.name = name_from_parts
  end

  private

  def name_from_parts
    [first_name, last_name].map { it.to_s.strip }.compact_blank.join(" ").presence || UNNAMED
  end
end
