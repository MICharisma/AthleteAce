# A team's record that holds for an inclusive date range, like a Stint.
# Missing bounds are open-ended.
module TeamDateRange
  extend ActiveSupport::Concern

  included do
    include SeedObservation

    belongs_to :team

    validates :end_date, comparison: { greater_than_or_equal_to: :start_date }, if: -> { start_date && end_date }

    scope :in_force_on, ->(date) {
      where("start_date IS NULL OR start_date <= ?", date).where("end_date IS NULL OR end_date >= ?", date)
    }
    scope :chronological, -> { order Arel.sql("start_date ASC NULLS FIRST") }
  end

  private

  def overlapping_ranges
    others = self.class.where(team_id: team_id).where.not(id: id)
    others = others.where("end_date IS NULL OR end_date >= ?", start_date) if start_date
    others = others.where("start_date IS NULL OR start_date <= ?", end_date) if end_date
    others
  end

  def ordered_range?
    !(start_date && end_date && end_date < start_date)
  end
end
