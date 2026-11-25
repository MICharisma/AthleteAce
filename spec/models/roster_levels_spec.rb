require "rails_helper"

RSpec.describe "Team roster levels" do
  let(:team) { create(:team) }
  let(:quest) { create(:quest) }

  it "snapshots the four completion targets" do
    players = create_list(:player, 17, team: team)
    targets = { "mastery" => 17, "fluency" => 15, "conversational" => 8, "introductory" => 3 }
    targets.each_key do |level|
      create(:highlight, quest: quest, achievement: create(:achievement, target: team, roster_level: level))
    end

    entries = create(:goal, quest: quest).goal_achievements

    expect(entries.to_h { |entry| [entry.roster_level, entry.target_player_count] }).to eq(targets)
    expect(entries).to all(have_attributes(required_player_ids: match_array(players.map(&:id))))
  end

  it "completes after three distinct correct answers at the adopted level" do
    players = create_list(:player, 4, team: team)
    achievement = create(:achievement, target: team, roster_level: "introductory")
    create(:highlight, quest: quest, achievement: achievement)
    goal = create(:goal, quest: quest)
    entry = goal.goal_achievements.sole
    achievement.update!(roster_level: "mastery")

    [players[0], players[0], players[1]].each do |player|
      attempt = create(:game_attempt, ace: goal.ace, subject_entity: player, is_correct: true)
      goal.record_answer!(attempt)
    end
    expect(entry.reload).to have_attributes(roster_level: "introductory", roster_progress: 2, completed_at: nil)
    expect(goal.reload.status).to eq("in_progress")

    [players[2], players[3]].each do |player|
      attempt = create(:game_attempt, ace: goal.ace, subject_entity: player, is_correct: true)
      goal.record_answer!(attempt)
    end
    expect(entry.reload).to have_attributes(roster_progress: 3, target_player_count: 3)
    expect(entry.completed_at).to be_present
    expect(goal.reload.status).to eq("completed")
  end
end
