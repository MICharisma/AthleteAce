require "rails_helper"

RSpec.describe "Play home and quest browsing" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team, territory: "Green Bay", mascot: "Packers", abbreviation: "GB") }
  let(:quest) { create(:quest, name: "NFC North Roll Call", description: "Know the teams and the players who make them go.") }

  before do
    rival = create(:team, league: team.league)
    create_list(:player, 10, team: team)
    create_list(:player, 5, team: rival)
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
    expect(page).to have_no_link("View quest")
    click_link "NFC North Roll Call"
    expect(page).to have_link("Continue Quest")
    click_button "20"
    expect(page).to have_css('.quest-session-length[aria-pressed="true"]', text: "20")
    expect(page).to have_link("Practice", href: /length=20/)
    expect(page).to have_link("Arena", href: /length=20/)
    click_link "Practice"
    expect(page).to have_css(".flash-card-page")
    expect(page).to have_content(team.name)
    visit quest_path(quest)
    click_button "30"
    click_button "Test"
    expect(page).to have_css(".round-question-prompt", text: /Is this player on the/i)
    expect(page).to have_css(".round-choice-name", text: "Yes")
    expect(page).to have_css(".round-choice-name", text: "No")
    expect(page).to have_css(".round-game-progress", text: %r{1 / (1[0-5]|[1-9])})
    visit quest_path(quest)
    click_link "Arena"
    expect(page).to have_content(team.name)
    expect(page).to have_button("Start round")
  end

  it "launches Practice, Test, and Arena at the selected length from a goal" do
    goal = ace.goals.find_by!(quest: quest)
    visit goal_path(goal)

    click_button "20"
    expect(page).to have_css('.quest-session-length[aria-pressed="true"]', text: "20")
    expect(page).to have_link("Practice", href: /length=20/)
    expect(page).to have_link("Arena", href: /length=20/)

    click_link "Practice"
    expect(page).to have_css(".flash-card-page")
    expect(page).to have_content(team.name)

    visit goal_path(goal)
    click_button "30"
    click_button "Test"
    expect(page).to have_css(".round-question-prompt", text: /Is this player on the/i)
    expect(page).to have_css(".round-choice-name", text: "Yes")
    expect(page).to have_css(".round-choice-name", text: "No")
    expect(page).to have_css(".round-game-progress", text: %r{1 / (1[0-5]|[1-9])})

    visit goal_path(goal)
    click_link "Arena"
    expect(page).to have_content(team.name)
    expect(page).to have_button("Start round")
  end

  it "launches Practice, Test, and Arena at the selected length from an achievement" do
    achievement = quest.achievements.first!
    visit achievement_path(achievement)

    click_button "20"
    expect(page).to have_css('.quest-session-length[aria-pressed="true"]', text: "20")
    expect(page).to have_link("Practice", href: /length=20/)
    expect(page).to have_link("Arena", href: /length=20/)

    click_link "Practice"
    expect(page).to have_css(".flash-card-page")
    expect(page).to have_content(team.name)

    visit achievement_path(achievement)
    click_button "30"
    click_button "Test"
    expect(page).to have_css(".round-question-prompt", text: /Is this player on the/i)
    expect(page).to have_css(".round-choice-name", text: "Yes")
    expect(page).to have_css(".round-choice-name", text: "No")
    expect(page).to have_css(".round-game-progress", text: %r{1 / (1[0-5]|[1-9])})

    visit achievement_path(achievement)
    click_link "Arena"
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
