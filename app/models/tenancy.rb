class Tenancy < ApplicationRecord
  include TeamDateRange

  ROLES = %w[home temporary shared].freeze

  belongs_to :stadium

  validates :role, inclusion: { in: ROLES }
  validate :nonoverlapping_home_period

  scope :home, -> { where role: "home" }

  private

  # A temporary or shared tenancy may sit inside a home range, and different
  # teams may share a stadium at the same time.
  def nonoverlapping_home_period
    return unless role == "home" && team_id && ordered_range?

    errors.add :base, "Home tenancies for this team cannot overlap" if overlapping_ranges.home.exists?
  end
end
