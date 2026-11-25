# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TierLists integration in AthleteAce", type: :request do
  it "renders /lists and /lists/:slug with team colors and player avatars" do
    league = create(:league)
    team = create(:team, league: league, territory: "Portland", mascot: "Trail Blazers",
                         abbreviation: "POR", primary_color: "#E03A3E", secondary_color: "#000000",
                         logo_url: "https://example.com/por.svg")
    list = TierLists::List.create!(name: "Western Contenders", privacy: :published, mode: :numbered)
    list.listed_items.create!(content: team, designation: team.name, expression: "POR")

    get "/lists"
    expect(response).to redirect_to("/playbooks")

    get "/playbooks"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Playbooks", "Western Contenders")

    get "/playbooks/#{list.slug}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Portland Trail Blazers")
    expect(response.body).to include("--tier-color-1: #E03A3E")
    expect(response.body).to include("--tier-color-2: #000000")
    expect(response.body).to include("https://example.com/por.svg")
    expect(response.body).to include("class=\"tier-entity-link\"", "href=\"/teams/#{team.id}\"")
    expect(response.body).to include("/playbooks/#{list.slug}/present")
    expect(response.body).not_to include("/playbooks/#{list.slug}/random")
    expect(response.body).not_to include("/playbooks/cable")
    expect(response.body).not_to include("All playbooks")

    get "/playbooks/#{list.slug}/present"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("tier-present-card", "Portland Trail Blazers", "View details ↗")

    get "/playbooks/new"
    expect(response).to redirect_to(new_ace_session_path)

    expect {
      post "/playbooks", params: { list: { name: "Logged Out List" } }
    }.not_to change(TierLists::List, :count)
    expect(response).to redirect_to(new_ace_session_path)
  end

  it "supports My Playbooks, Bookbag toggling, and the Builder JSON API" do
    ace = create(:ace)
    sign_in ace
    list = TierLists::List.create!(name: "Clutch Shooters", owner: ace, privacy: :published)

    get "/playbooks/mine"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Playbooks", "Clutch Shooters", "+ Bookbag")

    get "/playbooks/new"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("tier-form-shell", "tier-form-sticky-bar", "New playbook", "Create playbook", "Ordering mode", "Visibility")

    patch "/playbooks/builder/bookbag", params: { list_id: list.id }, as: :json
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["in_bookbag"]).to be(true)
    expect(json["bookbag"].map { |l| l["name"] }).to include("Clutch Shooters")

    player = create(:player)
    get "/players"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("draggable=\"true\"", "data-tier-listable-type=\"Player\"", "data-tier-listable-id=\"#{player.id}\"")

    post "/playbooks/builder/items", params: { list_id: list.id, content_type: "Player", content_id: player.id }, as: :json
    expect(response).to have_http_status(:created)
    expect(list.listed_items.reload.map(&:content)).to include(player)
  end
end
