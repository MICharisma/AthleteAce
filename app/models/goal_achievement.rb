class GoalAchievement < ApplicationRecord
  belongs_to :goal
  belongs_to :achievement

  scope :completed, -> { where.not(completed_at: nil) }

  def target_player_count
    required_player_count || required_player_ids.size
  end

  def roster_progress
    [progress, target_player_count].min
  end

  def progress
    (player_ids & required_player_ids).size
  end
end
