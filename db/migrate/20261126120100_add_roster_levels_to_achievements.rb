class AddRosterLevelsToAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :achievements, :roster_level, :string
    add_column :goal_achievements, :roster_level, :string
    add_column :goal_achievements, :required_player_count, :integer
  end
end
