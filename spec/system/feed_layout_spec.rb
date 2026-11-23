require "rails_helper"

RSpec.describe "Feed layout", type: :system do
  let(:author) { create(:ace, username: "wrigley_wes", display_name: "Wes Miller") }
  let(:league) { create(:mlb, sport: create(:baseball)) }
  let(:team) { create(:team, league: league, territory: "Chicago", mascot: "Cubs", abbreviation: "CHC", primary_color: "#0E3386", secondary_color: "#CC3433") }
  let(:player) { create(:player, team: team, first_name: "Nico", last_name: "Hoerner") }
  let!(:post) do
    buy_credit(author, amount: 2000)
    submit_credit(ace: author, target: player, message: "Outstanding work turning two in the final inning", bid: 125).tap { |post| review_post(post, action: "approve") }
  end

  before { phone_viewport }

  it "fits the feed, walls and standings for a visitor on a phone" do
    expect_pages_to_fit feed_path, team_path(team, side: "feed"), player_path(player, side: "feed"), shout_out_leaderboard_path
  end

  it "fits a fan's shout-out pages on a phone" do
    sign_in author
    expect_pages_to_fit feed_path, shout_outs_path, shout_out_path(post), new_shout_out_draft_path(target_type: "Player", target_id: player.id), wallet_path, posting_status_path
  end

  it "keeps the feed's search and sport filters wide enough to use" do
    visit feed_path
    expect(rect("#" + find_field("Search live shout-outs")[:id])["width"]).to be >= 200
    expect(rect("#" + find_field("Sport")[:id])["width"]).to be >= 200
  end
end
