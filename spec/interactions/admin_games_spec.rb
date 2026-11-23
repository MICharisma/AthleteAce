require "rails_helper"

RSpec.describe "Admin game directory" do
  let(:league) { create(:nba) }
  let(:game) { Game.create!(context: league, name: "Herons vs Foxes", begin_date: Date.new(2024, 11, 2), entity_code: "HBL:GAME:001") }

  before do
    campaign = Campaign.create!(team: create(:team, league: league, territory: "Harbor", mascot: "Herons"), season: create(:season, league: league, year: create(:year, number: 2024)))
    player = create(:player, first_name: "Jordan", last_name: "Reed", sport: league.sport, team: nil)
    Appearance.create!(contestant: Contestant.create!(contest: game, campaign: campaign), player: player, jersey_number: "00", starter: nil, statistics: { points: 18, minutes: 34 })
    roster = Roster.create!(campaign: campaign, kind: "game_availability", coverage: "complete", effective_on: game.begin_date, details: { game_code: game.entity_code })
    RosterEntry.create!(roster: roster, player: player, status: "active", jersey_number: "00")
    sign_in create(:ace, :admin)
  end

  it "finds a game by code among games with recorded appearances" do
    visit admin_catalog_records_path
    click_link "Games"
    fill_in "Search games", with: "HBL:GAME:001"
    select "Recorded appearances", from: "Appearances"
    click_button "Filter games"
    expect(page).to have_content("1 matching game")
    expect(page).to have_link(game.name, href: admin_game_path(game))
  end

  it "shows appearances with statistics and an unknown starter" do
    visit admin_game_path(game)
    expect(page).to have_content("Jordan Reed")
    expect(page).to have_content('"points":18')
    expect(page).to have_content("Unknown")
  end

  it "switches between roster entries and appearances" do
    visit admin_game_path(game)
    click_link "Roster entries"
    expect(page).to have_content("Coverage: complete")
    expect(page).to have_content("active")
    click_link "Appearances"
    expect(page).to have_content('"points":18')
    expect(page).to have_no_content("Coverage: complete")
  end
end
