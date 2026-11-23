require "rails_helper"

RSpec.describe "Continuing quest practice from a round" do
  let(:ace) { create(:ace) }
  let(:players) { [ %w[Jalen Brunson], %w[Josh Hart], %w[Mikal Bridges] ].map { |first, last| create(:player, first_name: first, last_name: last) } }
  let(:group) { PlayerGroup.create!(name: "Knicks backcourt", players: players.first(2)) }
  let(:next_group) { PlayerGroup.create!(name: "Knicks wings", players: players.last(2)) }
  let(:achievement) { create(:achievement, target: group, name: "Learn every player in the New York backcourt") }
  let(:next_achievement) { create(:achievement, target: next_group, name: "Learn every player on the New York wings") }
  let(:round) do
    quest = create(:quest, name: "Learn New York's rotation")
    create(:highlight, quest: quest, achievement: achievement, position: 0)
    create(:highlight, quest: quest, achievement: next_achievement, position: 1)
    entry = create(:goal, ace: ace, quest: quest).goal_achievements.find_by!(achievement: achievement)
    GameRoundSetup.new(game_type: "name_ciphers", player_group_id: group.id, goal_achievement_id: entry.id).start!(ace)
  end

  before do
    round.questions.each_with_index do |question, position|
      round.answer!(at: position, choice_id: position.zero? ? question.fetch("target_id") : nil)
      round.advance!(at: position)
    end
    sign_in ace
  end

  def finish_remaining_names
    visit summary_game_round_path(round)
    click_link "Continue achievement: #{achievement.name}"
    click_button "Start round"
    find(".round-choice[value='#{ace.game_rounds.last.question.fetch('target_id')}']").click
    click_button "Round summary"
  end

  it "shows achievement progress on the summary and continues with the remaining names" do
    visit summary_game_round_path(round)
    expect(page).to have_css(".round-learning-progress", text: "1 of 2 players answered correctly since adoption")
    click_link "Continue achievement: #{achievement.name}"
    expect(page).to have_select("Members to practice", selected: "Not yet answered correctly")
    expect(page).to have_content("1 player available")
  end

  it "completes the achievement and sets up the next one" do
    finish_remaining_names
    expect(page).to have_content("Achievement complete")
    click_link "Next achievement: #{next_achievement.name}"
    expect(page).to have_content("1 player available")
    expect(page).to have_select("Player group", selected: next_group.name)
  end
end
