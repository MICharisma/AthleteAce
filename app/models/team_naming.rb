class TeamNaming < ApplicationRecord
  include TeamDateRange

  belongs_to :nickname, optional: true

  validate :nonoverlapping_period

  def name
    display_name.presence || [ territory, nickname&.text ].compact_blank.join(" ")
  end

  private

  def nonoverlapping_period
    return unless team_id && ordered_range?

    errors.add :base, "Namings for this team cannot overlap" if overlapping_ranges.exists?
  end
end
