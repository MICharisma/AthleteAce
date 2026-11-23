require "rails_helper"

RSpec.describe "My teams on Feed" do
  it "keeps personal teams, league filters and practice links usable" do
    ace = create(:ace)
    league = create(:league, name: "NBA")
    team = create(:team, league: league, territory: "New York", mascot: "Knicks", abbreviation: "NYK")
    other = create(:team, territory: "Chicago", mascot: "Cubs", abbreviation: "CHC")
    create(:team, league: league)
    create(:player, team: team)
    ace.follows.create!(followable: team)
    affinity = create(:spectrum, name: "Affinity")
    create(:rating, ace: ace, rated: other, spectrum: affinity, value: 250)
    sign_in ace
    visit feed_path
    within('[aria-label="Feed views"]') { click_link "My teams" }
    expect(page).to have_css(".feed-team-card", count: 2)
    expect(page).to have_content("Following")
    expect(page).to have_content("High Affinity")
    select "NBA", from: "League"
    click_button "Search posts"
    expect(page).to have_css(".feed-team-card", count: 1)
    expect(page).to have_css(".feed-team-card", text: team.name)
    expect(page).not_to have_css(".feed-team-card", text: other.name)
    page.refresh
    expect(page).to have_select("League", selected: "NBA")
    within(".feed-team-card") { click_link "Practice team" }
    expect(page).to have_checked_field("round_team_#{team.id}")
    expect(page).to have_content("1 player available")
    visit feed_path(view: "my_teams", league_id: league.id)
    click_link "Clear filters"
    expect(page).to have_css(".feed-team-card", count: 2)
    expect(page).to have_select("League", selected: "All leagues")
  end
end
