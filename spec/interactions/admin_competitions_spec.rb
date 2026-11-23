require "rails_helper"

RSpec.describe "Admin competition directory" do
  let(:admin) { create(:ace, :admin) }
  let(:league) { create(:league, name: "Harbor Basketball League", sport: create(:sport, name: "Basketball")) }
  let(:other_league) { create(:league, name: "Coastal Basketball League", sport: league.sport) }
  let(:year) { create(:year, number: 2024) }
  let(:season) { create(:season, league: league, year: year) }
  let(:other_season) { create(:season, league: other_league, year: year) }
  let(:cup) { Contest.create!(context: league.sport, kind: "cup", name: "Harbor Invitational Cup", begin_date: Date.new(2024, 10, 20), end_date: Date.new(2024, 11, 2), entity_code: "BASKETBALL:CUP:HARBOR:2024", format_rules: { rounds: [ { key: "final", name: "Final", best_of: 3 } ], qualification: "Invited clubs" }) }
  let(:game) { Game.create!(context: league.sport, name: "Herons vs Foxes", begin_date: Date.new(2024, 11, 2)) }

  before do
    campaign = Campaign.create!(team: create(:team, territory: "Harbor", mascot: "Herons", league: league), season: season)
    other_campaign = Campaign.create!(team: create(:team, territory: "Coastal", mascot: "Foxes", league: other_league), season: other_season)
    entrant = Contestant.create!(contest: cup, campaign: campaign)
    Contestant.create!(contest: cup, campaign: other_campaign)
    TitleAward.create!(contest: cup, winner: entrant, key: "cup", name: "Invitational champions", awarded_on: Date.new(2024, 11, 2))
    [ campaign, other_campaign ].each { |entry| Contestant.create!(contest: game, campaign: entry) }
    ContestGame.create!(contest: cup, game: game, metadata: { round: "final", game_number: 1 })
    sign_in admin
  end

  it "finds a competition by code and recorded awards" do
    visit admin_catalog_records_path
    click_link "Competitions"
    fill_in "Search competitions", with: "HARBOR:2024"
    select "Recorded awards", from: "Titles"
    click_button "Filter competitions"
    expect(page).to have_content("1 matching competition")
    expect(page).to have_link(cup.name)
  end

  it "shows a cross-league cup's entrants, seasons and rules" do
    visit admin_competition_path(cup)
    expect(page).to have_content("2 recorded entrants")
    expect(page).to have_content("Assigned season: Not set")
    expect(page).to have_content("Best of 3")
    expect(page).to have_content(season.name)
    expect(page).to have_content(other_season.name)
    find("summary", text: "All recorded rules").click
    expect(page).to have_content("Invited clubs")
  end

  it "lists the cup's title awards" do
    visit admin_competition_path(cup)
    click_link "Title awards"
    expect(page).to have_content("Invitational champions")
    expect(page).to have_content("Harbor Herons")
  end

  it "links from the cup to its games and back" do
    visit admin_competition_path(cup)
    click_link "View games"
    expect(page).to have_select("Competition", selected: cup.name)
    click_link game.name
    expect(page).to have_content("Final · Game 1")
    click_link cup.name
    expect(page).to have_current_path(admin_competition_path(cup))
  end
end
