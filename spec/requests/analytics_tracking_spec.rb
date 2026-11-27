require "rails_helper"

RSpec.describe "Analytics tracking", type: :request do
  let(:ace) { create(:ace) }
  let(:player) { create(:player) }

  it "records an anonymous visit with first-party cookies, masked IP, and app-analytics metadata" do
    get feed_path, headers: { "REMOTE_ADDR" => "203.0.113.42" }

    expect(response).to have_http_status(:ok)
    visit = Ahoy::Visit.sole
    expect(visit.user).to be_nil
    expect(visit.ip).to eq("203.0.113.0")
    expect(cookies["ahoy_visit"]).to eq(visit.visit_token)
    expect(cookies["ahoy_visitor"]).to eq(visit.visitor_token)

    context = JSON.parse(Nokogiri::HTML(response.body).at_css('meta[name="app-analytics"]')["content"])
    expect(context).to include("side" => "feed", "page_type" => "feed.index", "path" => "/feed", "signed_in" => false, "enabled" => true)
  end

  it "accepts browser events on the active visit without minting orphan visits" do
    get feed_path
    visit = Ahoy::Visit.sole
    context = JSON.parse(Nokogiri::HTML(response.body).at_css('meta[name="app-analytics"]')["content"])

    post "/ahoy/events",
         params: {
           visit_token: cookies["ahoy_visit"],
           visitor_token: cookies["ahoy_visitor"],
           events: [ { name: "page_viewed", properties: context.except("enabled") } ]
         },
         as: :json

    expect(response).to have_http_status(:ok)
    expect(Ahoy::Visit.count).to eq(1)
    expect(Ahoy::Event.where(name: "page_viewed").sole.visit).to eq(visit)
  end

  it "stitches server-side game attempts onto the signed-in ace's active visit" do
    sign_in ace
    get strength_path
    visit = Ahoy::Visit.sole
    expect(visit.user).to eq(ace)

    post game_attempts_path,
         params: {
           game_attempt: {
             game_type: "player_team_match",
             time_elapsed_ms: 1200,
             subject_entity_type: "Player",
             subject_entity_id: player.id,
             chosen_entity_type: "Team",
             chosen_entity_id: player.team_id
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    event = Ahoy::Event.where(name: "game_attempt_saved", user: ace).sole
    expect(event.visit).to eq(visit)
    expect(Ahoy::Visit.count).to eq(1)
  end

  it "keeps visits and events while nullifying user_id when an ace is deleted" do
    sign_in ace
    get feed_path
    post game_attempts_path,
         params: {
           game_attempt: {
             game_type: "player_team_match",
             time_elapsed_ms: 1200,
             subject_entity_type: "Player",
             subject_entity_id: player.id,
             chosen_entity_type: "Team",
             chosen_entity_id: player.team_id
           }
         },
         as: :json

    ace.destroy!

    expect(Ahoy::Visit.sole.user_id).to be_nil
    expect(Ahoy::Event.where(name: "game_attempt_saved").sole.user_id).to be_nil
  end

  it "excludes admins, moderators, and opt-out cookies while keeping cross-actor fan events" do
    moderator = create(:ace, moderator: true)
    sign_in moderator
    get feed_path
    expect(JSON.parse(Nokogiri::HTML(response.body).at_css('meta[name="app-analytics"]')["content"])["enabled"]).to be(false)

    post "/ahoy/events",
         params: { visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, events: [ { name: "page_viewed", properties: {} } ] },
         as: :json
    expect(response).to have_http_status(:ok)
    expect(Ahoy::Visit.count).to eq(0)
    expect(Ahoy::Event.count).to eq(0)

    Current.ahoy_tracker = Ahoy::Tracker.new(request: ActionDispatch::Request.empty, user: moderator)
    Ahoy::Event.track("shout_out_published", user: ace, shout_out_id: SecureRandom.uuid)
    Current.reset

    published = Ahoy::Event.where(name: "shout_out_published", user: ace).sole
    expect(published.visit.user).to eq(ace)

    sign_out moderator
    cookies[:athleteace_analytics_exclude] = "1"
    post ace_registration_path, params: {
      ace: { username: "opted_out_ace", display_name: "Opted Out", email: "opted-out@example.com", password: "password123", password_confirmation: "password123" }
    }
    expect(Ahoy::Event.where(name: "signup_completed")).to be_empty
    expect(Ahoy::Visit.where.not(user: ace)).to be_empty
  end
end
