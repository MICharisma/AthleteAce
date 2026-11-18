class StaffTenure < ApplicationRecord
  include SeedObservation
  include PartialDates

  ROLES = %w[coach staff broadcaster].freeze

  belongs_to :figure
  belongs_to :organization
  belongs_to :team, optional: true

  partial_dates :start_date, :end_date, range: %i[start_date end_date]

  enum :role, ROLES.index_with(&:itself), validate: true
  validates :title, :entity_code, :source, presence: true
  validates :entity_code, uniqueness: true
  validate :ongoing_has_no_end

  scope :chronological, -> { order(Arel.sql("start_date DESC NULLS LAST"), :id) }

  private

  def ongoing_has_no_end
    errors.add :end_date, "must be absent for an ongoing appointment" if ongoing? && end_date.present?
  end
end
