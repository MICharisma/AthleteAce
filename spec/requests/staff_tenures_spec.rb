require "rails_helper"

RSpec.describe "People and staff appointments", type: :request do
  let(:organization) { create :organization, name: "Harbor Athletics" }
  let(:team) { create :team }
  let(:figure) { create(:player, first_name: "Jordan", last_name: "Reyes").figure }

  it "lists organization appointments, their team context, precision and sources" do
    create :staff_tenure, figure: figure, organization: organization, team: team,
      title: "Head coach", start_date: "2021", end_date: "2024-06"
    create :staff_tenure, organization: organization, role: "staff", title: "Performance director", ongoing: true
    get organization_path(organization)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(figure.name, "Head coach", "2021 to 2024-06", "Team context:", team.name,
      "Organization-wide", "Unknown start to Present", "Organization staff directory", figure_path(figure))
  end

  it "shows a broadcaster's employer separately from team coverage and excludes organization-wide appointments" do
    network = create :organization, name: "Harbor Sports Network"
    create :staff_tenure, :broadcaster, figure: figure, organization: network, team: team, start_date: "2025-10", ongoing: true
    create :staff_tenure, organization: network, title: "Network executive"
    get team_path(team, tab: "staff", side: "feed")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(figure.name, network.name, "Color commentator", "2025-10 to Present", 'data-side="feed"')
    expect(response.body).not_to include("Network executive")
  end

  it "connects one figure's athletic profile and coaching and broadcasting history" do
    create :staff_tenure, figure: figure, organization: organization, title: "Assistant coach", end_date: "2020"
    create :staff_tenure, :broadcaster, figure: figure
    get figure_path(figure)
    expect(response).to have_http_status(:ok)
    player = figure.players.sole
    expect(response.body).to include("Athletic profile: #{player.sport.name}", player_path(player), "Assistant coach", "Color commentator")
    expect(response.body).to include("Unknown start to Unknown end")
    get player_path(player)
    expect(response.body).to include(figure_path(figure), "Coaching, staff and broadcasting history")
  end

  it "renders empty staff collections and figures without athletic profiles" do
    get figure_path(create(:figure, name: "María Calderón"))
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("María Calderón", "No coaching, staff or broadcasting appointments recorded.")
    expect(response.body).not_to include("Athletic profile:")
    get team_path(team, tab: "staff")
    expect(response.body).to include("No coaching, staff or broadcasting appointments recorded.")
  end

  it "does not turn an unsafe evidence URL into a link" do
    create :staff_tenure, figure: figure, organization: organization, source: { "url" => "javascript:alert(1)", "title" => "Interview" }
    get organization_path(organization)
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('a[href^="javascript:"]')).to be_empty
  end

  it "preserves the browsing side for public figure pages even for administrators" do
    sign_in create(:ace, admin: true)
    get figure_path(figure, side: "feed")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-side="feed"')
  end
end
