require "rails_helper"

RSpec.describe "Seasonal Team Match" do
  let(:ace) { create(:ace) }
  let(:league) { create(:league, name: "NBA") }
  let(:season) { create(:season, league: league, label: "2025–26") }
  let(:knicks) { create(:team, league: league, territory: "New York", mascot: "Knicks") }
  let(:nets) { create(:team, league: league, territory: "Brooklyn", mascot: "Nets") }
  let(:round) { ace.game_rounds.last }

  before do
    [ knicks, nets ].each { |team| Activation.create!(player: create(:player, team: nil, active: false), campaign: Campaign.create!(team: team, season: season)) }
    sign_in ace
  end

  def start_season_round
    visit new_game_round_path(league_id: league.id, team_ids: [ knicks.id, nets.id ])
    click_link "Use #{season.name} · 2 players"
    click_button "Start round"
  end

  it "offers a season's rosters when the chosen teams have no current players" do
    visit new_game_round_path(league_id: league.id, team_ids: [ knicks.id, nets.id ])
    expect(page).to have_content("0 players available")
    expect(page).to have_button("Start round", disabled: true)
    expect(page).to have_content("No current-team player data for this selection.")
    click_link "Use #{season.name} · 2 players"
    expect(page).to have_content("2 players available")
    expect(page).to have_button("Start round", disabled: false)
    expect(page).to have_checked_field("round_team_#{knicks.id}")
    expect(page).to have_checked_field("round_team_#{nets.id}")
    expect(page).to have_no_field("Include inactive players")
  end

  it "asks about the chosen season and saves it with the round" do
    start_season_round
    expect(page).to have_css(".round-game-progress", text: "1 / 2")
    expect(page).to have_css(".round-question-prompt", text: /#{Regexp.escape(season.name)}/i)
    expect(round.scope.fetch("season_id")).to eq(season.id)
  end

  it "drills a missed historical answer from Play without assigning current teams" do
    start_season_round
    find(".round-skip").click
    question = round.reload.questions.first
    visit strength_path
    within(".play-misses") do
      expect(page).to have_content(season.name)
      click_button "Drill these 1"
    end
    expect(ace.game_rounds.last.questions.sole.except("game_type")).to eq(question)
    find(".round-choice[value='#{question.fetch('target_id')}']").click
    expect(page).to have_css(".round-feedback", text: /Correct/i)
    expect(Player.where.not(team_id: nil)).to be_empty
  end

  it "keeps the season when replaying Team Match and drops it for Guess the Division" do
    start_season_round
    visit new_game_round_path(round.scope)
    expect(page).to have_select("Roster season", selected: season.name)
    choose "Guess the Division"
    expect(page).to have_no_field("Roster season")
    expect(page).to have_no_content("is supported for Team Match only")
  end
end
