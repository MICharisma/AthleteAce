require "rails_helper"

RSpec.describe "Admin player history navigation" do
  let(:sport) { create(:sport, name: "Basketball") }
  let(:league) { create(:league, sport: sport, name: "Harbor Basketball League") }
  let(:team) { create(:team, territory: "Harbor", mascot: "Herons", league: league) }
  let(:player) { create(:player, first_name: "Jordan", last_name: "Reed", team: nil, sport: sport) }
  let(:game) { Game.create!(context: league, name: "Herons vs Foxes", begin_date: Date.new(2024, 11, 2)) }

  before do
    campaign = Campaign.create!(team: team, season: create(:season, league: league, year: create(:year, number: 2024)))
    organization = create(:organization, name: "Harbor Basketball Club")
    contract = Contract.create!(player: player, organization: organization, start_date: Date.new(2024, 10, 1))
    event = Transaction.create!(kind: "assignment", effective_on: Date.new(2024, 10, 2))
    TransactionPlayer.create!(event: event, player: player, to_team: team, to_organization: organization)
    Stint.create!(player: player, team: team, contract: contract, start_transaction: event, start_date: Date.new(2024, 10, 2))
    roster = Roster.create!(campaign: campaign, kind: "game_availability", coverage: "partial", effective_on: Date.new(2024, 11, 2))
    RosterEntry.create!(roster: roster, player: player, status: "active", jersey_number: "00")
    Appearance.create!(contestant: Contestant.create!(contest: game, campaign: campaign), player: player, starter: false, statistics: { points: 0 })
    sign_in create(:ace, :admin)
  end

  it "opens from the player's profile data and summarizes the organization and team" do
    visit edit_admin_catalog_record_path(player, kind: "players")
    click_link "Player history"
    expect(page).to have_content("Current profile team: Unassigned")
    expect(page).to have_content("Harbor Basketball Club")
    expect(page).to have_content("Harbor Herons")
    click_link "Edit profile data"
    expect(page).to have_current_path(edit_admin_catalog_record_path(player, kind: "players"))
  end

  it "explains that an organization contract doesn't assign a team" do
    visit admin_player_history_path(player)
    click_link "Contracts (1)"
    expect(page).to have_content("Organization contracts do not establish a team assignment")
    expect(page).to have_content("2024-10-01")
  end

  it "dates a transaction to the day it was recorded" do
    visit admin_player_history_path(player)
    click_link "Transactions (1)"
    expect(page).to have_content("day resolution")
    expect(page).to have_content("2024-10-02")
  end

  it "shows a partial game roster with the jersey worn" do
    visit admin_player_history_path(player)
    click_link "Rosters (1)"
    expect(page).to have_content("partial")
    expect(page).to have_content("00")
  end

  it "links an appearance's game and statistics, and back to the player" do
    visit admin_player_history_path(player)
    click_link "Appearances (1)"
    expect(page).to have_link(game.name, href: admin_game_path(game))
    expect(page).to have_content('"points":0')
    click_link game.name
    click_link player.name
    expect(page).to have_current_path(admin_player_history_path(player))
  end
end
