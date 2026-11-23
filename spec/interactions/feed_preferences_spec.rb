require "rails_helper"

RSpec.describe "My teams on Feed" do
  let(:ace) { create(:ace) }
  let(:league) { create(:league, name: "NBA") }
  let(:team) { create(:team, league: league, territory: "New York", mascot: "Knicks", abbreviation: "NYK") }
  let(:other) { create(:team, territory: "Chicago", mascot: "Cubs", abbreviation: "CHC") }

  before do
    create(:team, league: league)
    create(:player, team: team)
    ace.follows.create!(followable: team)
    create(:rating, ace: ace, rated: other, spectrum: create(:spectrum, name: "Affinity"), value: 250)
    sign_in ace
  end

  it "lists followed and highly rated teams" do
    visit feed_path
    within('[aria-label="Feed views"]') { click_link "My teams" }
    expect(page).to have_css(".feed-team-card", count: 2)
    expect(page).to have_content("Following")
    expect(page).to have_content("High Affinity")
  end

  it "filters my teams by league and keeps the filter through a refresh" do
    visit feed_path(view: "my_teams")
    select "NBA", from: "League"
    click_button "Search posts"
    expect(page).to have_css(".feed-team-card", count: 1)
    expect(page).to have_css(".feed-team-card", text: team.name)
    refresh
    expect(page).to have_select("League", selected: "NBA")
  end

  it "practices a team from its card" do
    visit feed_path(view: "my_teams", league_id: league.id)
    within(".feed-team-card") { click_link "Practice team" }
    expect(page).to have_checked_field("round_team_#{team.id}")
    expect(page).to have_content("1 player available")
  end

  it "clears the league filter" do
    visit feed_path(view: "my_teams", league_id: league.id)
    click_link "Clear filters"
    expect(page).to have_css(".feed-team-card", count: 2)
    expect(page).to have_select("League", selected: "All leagues")
  end
end
