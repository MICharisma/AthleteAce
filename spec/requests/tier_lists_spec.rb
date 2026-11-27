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

  it "supports Quests and Achievements as listed items and exposes curation affordances" do
    ace = create(:ace)
    team = create(:team, territory: "Boston", mascot: "Celtics", abbreviation: "BOS",
                         primary_color: "#007A33", secondary_color: "#BA9653",
                         logo_url: "https://example.com/bos.svg")
    achievement = create(:achievement, name: "Celtics Fluency", target: team, roster_level: "fluency")
    quest = create(:quest, name: "Atlantic Challenge", description: "Master Atlantic teams.")
    create(:highlight, quest: quest, achievement: achievement, required: true)
    list = TierLists::List.create!(name: "Study Path", owner: ace, privacy: :published)

    sign_in ace

    post "/playbooks/builder/items", params: { list_id: list.id, content_type: "Quest", content_id: quest.id }, as: :json
    expect(response).to have_http_status(:created)

    post "/playbooks/builder/items", params: { list_id: list.id, content_type: "Achievement", content_id: achievement.id }, as: :json
    expect(response).to have_http_status(:created)

    expect(list.listed_items.reload.map(&:content)).to contain_exactly(quest, achievement)

    get "/playbooks/#{list.slug}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      quest.name, achievement.name,
      "--tier-color-1: #4A6500", "--tier-color-1: #B45309",
      "Quest · 1 required", "Achievement · #{team.name} · Roster fluency",
      "href=\"/quests/#{quest.id}\"", "href=\"/achievements/#{achievement.id}\""
    )

    get "/playbooks/#{list.slug}/present"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("tier-present-card", quest.name)

    get "/playbooks/#{list.slug}/present", params: { page: 2 }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("tier-present-card", achievement.name)

    goal = ace.adopt_quest(quest)

    [
      [ "/quests", "Quest", quest.id ],
      [ "/quests/#{quest.id}", "Quest", quest.id ],
      [ "/achievements", "Achievement", achievement.id ],
      [ "/achievements/#{achievement.id}", "Achievement", achievement.id ],
      [ "/goals/#{goal.id}", "Achievement", achievement.id ]
    ].each do |path, expected_type, expected_id|
      get path
      expect(response).to have_http_status(:ok), path
      doc = response.parsed_body
      expect(doc.at_css("[draggable='true'][data-tier-listable-type='#{expected_type}'][data-tier-listable-id='#{expected_id}']")).to be_present, "missing draggable #{expected_type} on #{path}"
      expect(doc.at_css(".engagements-radial")).to be_present, "missing engagements radial bar on #{path}"
      expect(doc.at_css(".playbook-item-action")).to be_present, "missing + Playbook button on #{path}"
    end

    pending_quest = create(:quest, created_by: ace, name: "Draft Quest")
    pending_achievement = create(:achievement, created_by: ace, name: "Draft Achievement", target: team)
    [ "/quests/#{pending_quest.id}", "/achievements/#{pending_achievement.id}" ].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      doc = response.parsed_body
      expect(doc.at_css(".engagements-radial")).to be_nil
      expect(doc.at_css(".playbook-item-action")).to be_nil
      expect(doc.at_css("[data-tier-listable-type]")).to be_nil
    end
  end
end
