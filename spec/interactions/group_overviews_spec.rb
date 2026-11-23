require "rails_helper"

RSpec.describe "Group practice from Play home" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team) }
  let(:group) do
    PlayerGroup.create!(name: "Knicks names", players: [
      create(:player, first_name: "Jalen", last_name: "Brunson", team: team),
      create(:player, first_name: "Josh", last_name: "Hart", team: create(:team, league: team.league), active: false)
    ])
  end

  # Plays a round on the group: the first name right, the second skipped.
  def play_round(correct: [ true, false ])
    round = GameRoundSetup.new(game_type: "name_ciphers", player_group_id: group.id).start!(ace)
    correct.each_with_index do |right, position|
      round.answer!(at: position, choice_id: right ? round.questions[position].fetch("target_id") : nil)
      round.advance!(at: position)
    end
  end

  before do
    play_round
    sign_in ace
  end

  it "shows a group's progress on Play home" do
    visit strength_path
    expect(page).to have_css(".play-groups .group-practice-card", count: 1)
    within(".play-groups") do
      expect(page).to have_content("1 of 2")
      expect(page).to have_link("Practice misses")
    end
  end

  it "starts practice on the remaining names from the home card" do
    visit strength_path
    within(".play-groups") { click_link "Practice remaining 1" }
    expect(page).to have_select("Members to practice", selected: "Not yet answered correctly")
    click_button "Start round"
    expect(page).to have_css(".round-game-progress", text: "1 / 1")
  end

  it "offers the whole group once every name is answered correctly" do
    remaining = Player.find(ace.game_rounds.last.questions.second.fetch("subject_id"))
    create(:game_attempt, ace: ace, subject_entity: remaining, is_correct: true)
    visit strength_path
    within(".play-groups") do
      expect(page).to have_content("2 of 2")
      expect(page).to have_link("Practice group")
      expect(page).to have_no_link("Practice misses")
      click_link "All groups"
    end
    expect(page).to have_css(".group-practice-card", count: 1)
    expect(page).to have_content("2 of 2")
  end
end
