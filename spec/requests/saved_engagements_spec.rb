require "rails_helper"

RSpec.describe "Saved engagements" do
  let(:ace) { create(:ace) }
  let(:player) { create(:player, first_name: "Jalen", last_name: "Brunson") }
  let(:headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before { sign_in ace }

  it "stores each mark under the signed-in account and lists it on Saved" do
    other = create(:ace)
    %w[bookmark favorite follow hide].each do |kind|
      post "/saved", params: { engageable_type: "Player", engageable_id: player.id, kind: kind, actor_id: other.id }, headers: headers
      expect(response).to have_http_status(:ok)
    end

    expect(ace.engagements.where(engageable: player).pluck(:kind)).to match_array(%w[bookmark favorite follow hide])
    expect(other.engagements).to be_empty

    get "/saved", params: { kind: "bookmark", type: "Player", q: "Brunson" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css(".engagements-saved-name").map(&:text)).to eq([player.name])
    expect(response.parsed_body.at_css("a.ace-brand")["href"]).to eq("/")
    expect(response.parsed_body.at_css(".shell-account-links a[href='/profile']")).to be_present
  end

  it "hides a player only in the marking account's browse list and accepts unhide from Saved" do
    player_url = Rails.application.routes.url_helpers.player_path(player)
    post "/saved", params: { engageable_type: "Player", engageable_id: player.id, kind: "hide" }, headers: headers
    hidden = ace.engagements.hide.sole

    get "/players"
    expect(response.parsed_body.at_css("#players a[href='#{player_url}']")).to be_nil

    delete "/saved/#{hidden.id}", headers: headers.merge("HTTP_REFERER" => "http://www.example.com/saved?kind=hide")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('action="refresh"')
    get "/players"
    expect(response.parsed_body.at_css("#players a[href='#{player_url}']")).to be_present

    sign_in create(:ace)
    ace.engagements.hide.create!(engageable: player)
    get "/players"
    expect(response.parsed_body.at_css("#players a[href='#{player_url}']")).to be_present
  end

  it "supports bookmark, favorite, follow, and hide on Quests and Achievements, filters /saved, and preserves moderation" do
    other = create(:ace)
    quest = create(:quest, name: "Pacific Division Sprint")
    achievement = create(:achievement, name: "Know the Pacific Roster", target: create(:team))
    pending_quest = create(:quest, created_by: other, name: "Pending Quest")
    pending_achievement = create(:achievement, created_by: other, name: "Pending Achievement")

    expect(Quest.visible_to(ace)).to include(quest)
    expect(Quest.visible_to(ace)).not_to include(pending_quest)
    expect(Achievement.visible_to(ace)).to include(achievement)
    expect(Achievement.visible_to(ace)).not_to include(pending_achievement)

    [ quest, achievement ].each do |record|
      %w[bookmark favorite follow hide].each do |kind|
        post "/saved", params: { engageable_type: record.class.name, engageable_id: record.id, kind: kind }, headers: headers
        expect(response).to have_http_status(:ok)
      end
      expect(ace.engagements.where(engageable: record).pluck(:kind)).to match_array(%w[bookmark favorite follow hide])
    end

    get "/saved", params: { kind: "bookmark", type: "Quest" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css(".engagements-saved-name").map(&:text)).to eq([ quest.name ])

    get "/saved", params: { kind: "favorite", type: "Achievement" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css(".engagements-saved-name").map(&:text)).to eq([ achievement.name ])

    get "/profile"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(quest.name, achievement.name)

    get "/quests"
    expect(response.parsed_body.at_css("#quest_#{quest.id}")).to be_nil
    get "/quests/#{quest.id}"
    expect(response).to have_http_status(:ok)

    get "/achievements"
    expect(response.parsed_body.at_css("#achievement_#{achievement.id}")).to be_nil
    get "/achievements/#{achievement.id}"
    expect(response).to have_http_status(:ok)

    sign_in other
    get "/quests"
    expect(response.parsed_body.at_css("#quest_#{quest.id}")).to be_present
    get "/achievements"
    expect(response.parsed_body.at_css("#achievement_#{achievement.id}")).to be_present

    sign_in ace
    hidden_quest = ace.engagements.hide.find_by!(engageable: quest)
    delete "/saved/#{hidden_quest.id}", headers: headers.merge("HTTP_REFERER" => "http://www.example.com/saved?kind=hide")
    expect(response).to have_http_status(:ok)
    get "/quests"
    expect(response.parsed_body.at_css("#quest_#{quest.id}")).to be_present

    hidden_achievement = ace.engagements.hide.find_by!(engageable: achievement)
    delete "/saved/#{hidden_achievement.id}", headers: headers.merge("HTTP_REFERER" => "http://www.example.com/saved?kind=hide")
    expect(response).to have_http_status(:ok)
    get "/achievements"
    expect(response.parsed_body.at_css("#achievement_#{achievement.id}")).to be_present
  end
end
