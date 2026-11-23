require "rails_helper"

RSpec.describe "Saved round layout", type: :system do
  let(:ace) { create(:ace) }
  let(:league) { create(:league, name: "Major League Baseball", sport: create(:sport, name: "Baseball")) }
  let(:team) { create(:team, territory: "New York", mascot: "Yankees", league: league, primary_color: "#FFFFFF", secondary_color: "#003087") }

  before do
    create(:player, team: team, first_name: "Aaron", last_name: "Judge", active: true)
    create(:player, team: create(:team, territory: "Boston", mascot: "Red Sox", league: league), first_name: "Rafael", last_name: "Devers", active: true)
    sign_in ace
    phone_viewport
  end

  it "fits setup, a question, its feedback and the summary on a phone" do
    visit new_game_round_path(league_id: league.id)
    expect(page).to have_content("2 players available")
    expect_no_horizontal_overflow
    click_button "Start round"
    expect(page).to have_css(".round-game-progress", text: "1 / 2")
    expect_no_horizontal_overflow
    click_button "I don’t know — show me"
    expect(page).to have_css(".round-feedback")
    expect_no_horizontal_overflow
    expect(page).to have_css(".round-game-progress", text: "2 / 2")
    click_button "I don’t know — show me"
    expect(page).to have_css("h1", text: /Round complete/i)
    expect_no_horizontal_overflow
  end

  it "fits team answer cards on a phone in light and dark themes" do
    visit new_game_round_path(team_id: team.id)
    click_button "Start round"
    expect(page).to have_css(".round-team-answer", count: 2)
    expect_no_horizontal_overflow
    page.execute_script("document.documentElement.dataset.theme = 'dark'")
    expect_no_horizontal_overflow
  end
end
