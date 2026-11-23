require "rails_helper"

RSpec.describe "Game history layout", type: :system do
  let(:ace) { create(:ace) }
  let(:team) { create(:team, territory: "New York", mascot: "Yankees") }
  let(:rival) { create(:team, territory: "Boston", mascot: "Red Sox", league: team.league) }

  before do
    create(:game_attempt, ace: ace, subject_entity: create(:player, team: team), chosen_entity: rival, is_correct: false)
    sign_in ace
    phone_viewport
  end

  it "fits game history on a phone" do
    visit strength_game_attempts_path
    expect(page).to have_content("1 mix-up")
    expect_no_horizontal_overflow
  end

  it "keeps a mix-up drill's start button above the tab bar" do
    visit strength_game_attempts_path
    find("a[aria-label='Drill New York Yankees and Boston Red Sox']").click
    page.scroll_to find_button("Start round"), align: :center
    expect(rect("input[value='Start round']")["bottom"]).to be <= rect(".shell-tabs-mobile")["top"]
  end
end
