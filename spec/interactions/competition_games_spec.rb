require "rails_helper"

RSpec.describe "Competition catalog" do
  it "browses from the competition format and title to the game's round" do
    league = create(:league, name: "MLS")
    team = create(:team, league: league, territory: "Miami", mascot: "Inter")
    campaign = Campaign.create!(team: team, season: create(:season, league: league))
    competition = Contest.create!(name: "MLS Cup Playoffs", kind: "playoffs", context: league,
      format_rules: { "rounds" => [ { "key" => "final", "name" => "Cup final", "best_of" => 1 } ] })
    entry = Contestant.create!(contest: competition, campaign: campaign)
    game = Game.create!(name: "Miami cup final", context: league)
    Contestant.create!(contest: game, campaign: campaign)
    ContestGame.create!(contest: competition, game: game, metadata: { "round" => "final", "game_number" => 1 })
    TitleAward.create!(contest: competition, winner: entry, key: "mls_cup", name: "MLS Cup")
    visit contest_path(competition)
    expect(page).to have_content("Cup final · Best of 1")
    expect(page).to have_content("MLS Cup · Miami Inter")
    click_link "Miami cup final"
    expect(page).to have_current_path(game_path(game))
    expect(page).to have_content("MLS Cup Playoffs")
    expect(page).to have_content("Final · Game 1")
  end
end
