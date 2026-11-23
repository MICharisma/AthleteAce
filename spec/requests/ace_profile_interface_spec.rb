require "rails_helper"

# Each example records what one reviewer sees on an ace's moderation profile.
# The snapshots in spec/snapshots/ace_moderation_profile/ are the reviewed
# record of every permutation; `bundle exec insta review` shows what changed.
RSpec.describe "Ace moderation profile" do
  let(:fan) { create(:ace, username: "bleacher_creature", display_name: "Rosa Diaz") }
  let(:moderator) { create(:ace, username: "fair_catch", display_name: "Jules Okafor", moderator: true) }
  let(:admin) { create(:ace, :admin, username: "front_office", display_name: "Dana Whitfield") }

  around { |example| travel_to(Time.utc(2026, 11, 2, 15)) { example.run } }

  def act(kind, ace:, actor: moderator, **attributes)
    Moderation::PostingAction.call(ace: ace, actor: actor, kind: kind, attributes: { request_key: SecureRandom.uuid, **attributes })
  end

  def outline_of(ace, as:, tab: nil)
    sign_in as
    get ace_profile_path(ace, tab: tab)
    expect(response).to have_http_status(:ok)
    response.body
  end

  it "shows a moderator every action and empty state for a new fan" do
    expect(outline_of(fan, as: moderator)).to match_snapshot(serializer: :interface)
  end

  it "shows a moderator the empty reports, actions and notes tabs for a new fan" do
    %w[reports actions notes].each do |tab|
      expect(outline_of(fan, as: moderator, tab: tab)).to match_snapshot("new_fan_#{tab}", serializer: :interface)
    end
  end

  it "shows a fan's submissions, warnings, mute and notes" do
    create(:quest, created_by: fan, name: "Know the Cubs starters")
    act "warn", ace: fan, reason: "Keep proposals clear"
    act "mute", ace: fan, reason: "Keep discussion about the players", duration_hours: "24", note: "Second warning this week"
    act "note", ace: fan, body: "Check back after the mute ends"
    %w[submissions actions notes].each do |tab|
      expect(outline_of(fan, as: moderator, tab: tab)).to match_snapshot("fan_history_#{tab}", serializer: :interface)
    end
  end

  it "withholds actions, reports and notes on a moderator's own profile" do
    %w[submissions reports notes].each do |tab|
      expect(outline_of(moderator, as: moderator, tab: tab)).to match_snapshot("own_profile_#{tab}", serializer: :interface)
    end
  end

  it "sends another moderator's account to an admin" do
    peer = create(:ace, username: "sixth_man", display_name: "Theo Park", moderator: true)
    expect(outline_of(peer, as: moderator)).to match_snapshot(serializer: :interface)
  end

  it "lets an admin end a moderator's mute early" do
    act "mute", ace: moderator, actor: admin, reason: "Pause new proposals", duration_hours: "168"
    expect(outline_of(moderator, as: admin)).to match_snapshot(serializer: :interface)
  end
end
