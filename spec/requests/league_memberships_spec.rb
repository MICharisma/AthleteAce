require "rails_helper"

RSpec.describe "Browsing league memberships", type: :request do
  before { sign_in create(:ace) }

  it "renders league-only and conference-only memberships" do
    team = create(:team)
    conference = create(:conference, league: team.league)
    memberships = [Membership.create!(team: team), Membership.create!(team: team, conference: conference)]

    memberships.each do |membership|
      get membership_path(membership)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(team.name, team.league.name)
    end
    get memberships_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(team.league.name, conference.name)
    get conference_path(conference)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(team.name)
  end

  it "renders and filters a division without a conference in HTML and JSON" do
    division = create(:division, conference: nil)
    team = create(:team, league: division.league)
    Membership.create!(team: team, division: division)

    get division_path(division)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(division.name, division.league.name, team.name)
    get divisions_path, params: { league_id: division.league_id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(division.name)
    get division_path(division, format: :json)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("league_id" => division.league_id, "conference_id" => nil,
      "conference" => { "id" => nil, "name" => nil }, "teams_count" => 1)
  end
end
