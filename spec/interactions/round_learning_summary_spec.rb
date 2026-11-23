require "rails_helper"

RSpec.describe "Continuing quest practice from a round" do
  it "finishes remaining names and advances to the next achievement" do
    ace = create(:ace)
    players = [ [ "Jalen", "Brunson" ], [ "Josh", "Hart" ], [ "Mikal", "Bridges" ] ].map do |first_name, last_name|
      create(:player, first_name: first_name, last_name: last_name)
    end
    group = PlayerGroup.create!(name: "Knicks backcourt", players: players.first(2))
    next_group = PlayerGroup.create!(name: "Knicks wings", players: players.last(2))
    quest = create(:quest, name: "Learn New York's rotation")
    achievement = create(:achievement, target: group, name: "Learn every player in the New York backcourt")
    next_achievement = create(:achievement, target: next_group, name: "Learn every player on the New York wings")
    create(:highlight, quest: quest, achievement: achievement, position: 0)
    create(:highlight, quest: quest, achievement: next_achievement, position: 1)
    goal = create(:goal, ace: ace, quest: quest)
    entry = goal.goal_achievements.find_by!(achievement: achievement)
    round = GameRoundSetup.new(game_type: "name_ciphers", player_group_id: group.id, goal_achievement_id: entry.id).start!(ace)
    round.questions.each_with_index do |question, position|
      round.answer!(at: position, choice_id: position.zero? ? question.fetch("target_id") : nil)
      round.advance!(at: position)
    end
    sign_in ace
    visit summary_game_round_path(round)
    expect(page).to have_css(".round-learning-progress", text: "1 of 2 players answered correctly since adoption")
    click_link "Continue achievement: #{achievement.name}"
    expect(page).to have_select("Members to practice", selected: "Not yet answered correctly")
    expect(page).to have_content("1 player available")
    click_button "Start round"
    expect(page).to have_css(".round-game-progress", text: "1 / 1")
    remaining_round = ace.game_rounds.last
    find(".round-choice[value='#{remaining_round.question.fetch('target_id')}']").click
    expect(page).to have_css(".round-feedback", text: /Correct/i)
    click_button "Round summary"
    expect(page).to have_content("Achievement complete")
    expect(page).to have_link("Next achievement: #{next_achievement.name}")
    click_link "Next achievement: #{next_achievement.name}"
    expect(page).to have_content("1 player available")
    expect(page).to have_select("Player group", selected: next_group.name)
  end
end
