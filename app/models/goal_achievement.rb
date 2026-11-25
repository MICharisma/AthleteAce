class GoalAchievement < ApplicationRecord
  belongs_to :goal
  belongs_to :achievement

  scope :completed, -> { where.not(completed_at: nil) }

  def progress
    (player_ids & required_player_ids).size
  end
end
