require "rails_helper"

RSpec.describe "Play home and quest browsing" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team, territory: "Green Bay", mascot: "Packers", abbreviation: "GB") }
  let(:quest) { create(:quest, name: "NFC North Roll Call", description: "Know the teams and the players who make them go.") }

  before do
    create(:team, league: team.league)
    create_list(:player, 10, team: team)
    achievement = create(:achievement, name: "Learn the Packers roster", target: team)
    create(:highlight, quest: quest, achievement: achievement)
    create(:goal, ace: ace, quest: quest, status: "in_progress")
    sign_in ace
  end

  it "starts and resumes a round, then explores quests" do
    visit strength_path
    expect(page).to have_content(/Make names stick\./i)
    expect(page).to have_content("NFC North Roll Call")
    within(".play-launch") { click_button "Quick round" }
    expect(page).to have_css(".round-game-progress", text: "1 / 10")
    click_button "Pause round"
    visit strength_path
    expect(page).to have_content("0 of 10 answered")
    within(".round-continue") { click_link "Continue" }
    expect(page).to have_button("Resume round")
    visit quests_path
    expect(page).to have_css(".quest-card", count: 1)
    click_link "View quest"
    expect(page).to have_link("Continue Quest")
    click_link "Practice"
    expect(page).to have_content(team.name)
    expect(page).to have_button("Start round")
  end
  it "drills unresolved misses, clears a corrected name and links today's player ratings" do
    player = team.players.first
    create(:game_attempt, ace: ace, subject_entity: player, is_correct: true)
    3.times { create(:game_attempt, ace: ace, subject_entity: player, is_correct: false) }
    visit strength_path
    expect(page).to have_content(/Day streak/i)
    expect(page).to have_content(/Names known/i)
    within(".play-misses") { expect(page).to have_content("Missed 3×") }
    click_button "Drill these 1"
    expect(page).to have_css(".round-game-progress", text: "1 / 1")
    find(".round-choice[value='#{team.id}']").click
    expect(page).to have_css(".round-feedback", text: /Correct/i)
    visit strength_path
    expect(page).to have_no_css(".play-misses")
    expect(page).to have_css(".play-scoreboard > div:last-child strong", text: "1")
    within(".play-rate-today") { click_link "Rate" }
    expect(page).to have_css("#player-ratings-title", text: /Player Ratings/i)
  end
end
