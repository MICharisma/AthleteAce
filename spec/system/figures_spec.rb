require "rails_helper"

RSpec.describe "Figure career pages", type: :system do
  it "connects an athletic profile with its shared coaching and broadcasting history" do
    sport = create :sport, name: "Basketball"
    team = create :team, league: create(:league, sport: sport), territory: "Oakland", mascot: "Herons"
    player = create :player, team: team, first_name: "Jordan", last_name: "Reyes"
    organization = create :organization, name: "Harbor Sports Group"
    create :staff_tenure, figure: player.figure, organization: organization, team: team,
      title: "Head coach", start_date: "2025", ongoing: true
    create :staff_tenure, :broadcaster, figure: player.figure, organization: organization

    visit player_path(player)
    click_link "Coaching, staff and broadcasting history"

    expect(page).to have_current_path(figure_path(player.figure), ignore_query: true)
    expect(page).to have_css("h1", text: /Jordan Reyes/i)
    expect(page).to have_content("Head coach")
    expect(page).to have_content("Color commentator")
    expect(page).to have_link("Harbor Sports Group", href: organization_path(organization), count: 2)

    click_link "Athletic profile: Basketball"

    expect(page).to have_current_path(player_path(player), ignore_query: true)
    expect(page).to have_link("Coaching, staff and broadcasting history", href: figure_path(player.figure))
  end
end
