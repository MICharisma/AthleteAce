require "rails_helper"

RSpec.describe "Name Cipher rounds" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team, territory: "New York", mascot: "Knicks") }
  let(:rival) { create(:team, league: team.league, territory: "Brooklyn", mascot: "Nets") }
  let(:season) { create(:season, league: team.league, label: "2025–26") }
  let(:round) { ace.game_rounds.last }

  before do
    { team => [ %w[Jalen Brunson], %w[Josh Hart] ], rival => [ %w[Nic Claxton], %w[Cam Thomas] ] }.each do |club, names|
      campaign = Campaign.create!(team: club, season: season)
      names.each { |first, last| Activation.create!(player: create(:player, team: nil, active: false, first_name: first, last_name: last), campaign: campaign) }
    end
    sign_in ace
  end

  def start_round
    visit new_game_round_path(season_id: season.id, team_ids: [ team.id, rival.id ])
    choose "Name Ciphers"
    click_button "Start round"
  end

  # Skips the first puzzle, then solves the rest with number keys.
  def finish_round_missing_the_first
    start_round
    click_button "I don’t know — show me"
    click_button "Next"
    1.upto(round.length - 1) do |position|
      question = round.questions.fetch(position)
      key = question.fetch("choices").index { |choice| choice.fetch("id") == question.fetch("target_id") } + 1
      find(".round-cipher-name").send_keys key.to_s
      expect(page).to have_css(".round-feedback", text: /Correct/i)
      click_button(position == round.length - 1 ? "Round summary" : "Next")
    end
  end

  it "sets up a round from the season's rosters for both chosen teams" do
    visit new_game_round_path(season_id: season.id, team_ids: [ team.id, rival.id ])
    choose "Name Ciphers"
    expect(page).to have_select("Roster season", selected: season.name)
    expect(page).to have_checked_field("round_team_#{team.id}")
    expect(page).to have_checked_field("round_team_#{rival.id}")
    expect(page).to have_content("4 players available")
  end

  it "shows a scrambled name instead of a portrait and keeps it through a refresh" do
    start_round
    expect(page).to have_css(".round-game-progress", text: "1 / 4")
    expect(page).to have_css(".round-choice", count: 4)
    expect(page).to have_css(".round-cipher-name", text: round.questions.first.fetch("scrambled_name"))
    expect(page).to have_no_css(".round-subject .entity-avatar")
    refresh
    expect(page).to have_css(".round-cipher-name", text: round.questions.first.fetch("scrambled_name"))
  end

  it "keeps the saved puzzles through a pause" do
    start_round
    saved = round.questions
    click_button "Pause round"
    click_button "Resume round"
    expect(round.reload.questions).to eq(saved)
  end

  it "scores number-key answers and links each player from the summary" do
    finish_round_missing_the_first
    expect(page).to have_content("3 / 4")
    missed = round.questions.first
    expect(page).to have_link(missed.fetch("subject_name"), href: player_path(missed.fetch("subject_id")))
  end

  it "plays again with the same game and season" do
    finish_round_missing_the_first
    click_link "Play again"
    expect(page).to have_checked_field("Name Ciphers")
    expect(page).to have_select("Roster season", selected: season.name)
  end

  it "drills only the missed puzzle" do
    finish_round_missing_the_first
    click_button "Drill misses"
    expect(page).to have_css(".round-game-progress", text: "1 / 1")
    expect(ace.game_rounds.last.questions.sole).to eq(round.questions.first)
  end

  it "records every answer in history and suggests rating a player from the round" do
    finish_round_missing_the_first
    visit strength_game_attempts_path(game_type: "name_ciphers")
    expect(page).to have_css(".history-attempt", count: 4)
    visit strength_path
    within(".play-rate-today") { expect(page).to have_content("Jalen Brunson") }
  end
end
