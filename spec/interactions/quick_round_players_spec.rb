require "rails_helper"

RSpec.describe "Quick practice for followed players" do
  let(:ace) { create(:ace) }
  let!(:tim) { create(:player, first_name: "Tim", last_name: "Duncan", team: nil, active: false) }
  let!(:manu) { create(:player, first_name: "Manu", last_name: "Ginobili", team: nil, active: false) }
  let(:round) { ace.game_rounds.last }

  before { sign_in ace }

  it "follows a retired player without a team" do
    visit player_path(tim)
    within("#follow_player_#{tim.id}") do
      click_button "Follow"
      expect(page).to have_button("Following")
    end
  end

  context "following two retired players" do
    before { [ tim, manu ].each { |player| ace.follows.create!(followable: player) } }

    it "builds a Quick round of their names" do
      visit strength_path
      within("main") { click_button "Quick round" }
      expect(page).to have_css(".round-game-progress", text: "1 / 2")
      expect(round.game_type).to eq("name_ciphers")
      expect(round.questions.map { |question| question.fetch("subject_id") }).to contain_exactly(tim.id, manu.id)
    end

    it "keeps both players when playing again" do
      visit strength_path
      within("main") { click_button "Quick round" }
      round.questions.each_with_index do |question, position|
        find(".round-choice[value='#{question.fetch('target_id')}']").click
        click_button(position == 1 ? "Round summary" : "Next")
      end
      expect(page).to have_css(".round-final-score", text: "2 / 2")
      click_link "Play again"
      expect(page).to have_content("2 players available")
      expect(page).to have_content("Tim Duncan")
      expect(page).to have_content("Manu Ginobili")
      expect(page).to have_checked_field("Name Ciphers")
    end
  end
end
