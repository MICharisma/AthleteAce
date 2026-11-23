require "rails_helper"

RSpec.describe "Browse entity navigation" do
  it "follows scoped links from a sport through a league to a team and stays on the play side" do
    league = create :league, name: "Pacific Basketball League", sport: create(:sport, name: "Basketball")
    team = create :team, league: league, territory: "Oakland", mascot: "Herons"
    create_list :player, 2, team: team
    visit sport_path(league.sport, side: "play")
    click_link league.name
    expect(page).to have_css("main h1", text: league.name, count: 1)
    expect(page).to have_css('body[data-side="play"]')
    click_link "View all teams"
    expect(page).to have_current_path(league_teams_path(league))
    click_link team.name
    expect(page).to have_css('body[data-side="play"]')
    expect(page).to have_content(league.name)
  end
end
