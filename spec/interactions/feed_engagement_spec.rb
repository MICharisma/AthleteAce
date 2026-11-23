require "rails_helper"

RSpec.describe "Feed engagement" do
  let(:author) { create(:ace) }
  let(:fan) { create(:ace) }
  let(:team) { create(:team, league: create(:mlb), territory: "Chicago", mascot: "Cubs", abbreviation: "CHC") }
  let(:nico) { create(:player, team: team, first_name: "Nico", last_name: "Hoerner") }
  let(:post) { submit_credit(ace: author, target: nico, message: "Tireless work in every inning", bid: 500) }
  let(:second) { submit_credit(ace: author, target: nico, message: "A spectacular catch", bid: 1) }

  before do
    buy_credit(author)
    third = submit_credit(ace: author, target: create(:player, team: team, first_name: "Pete", last_name: "Crow-Armstrong"), message: "A brilliant finish", bid: 1)
    [ post, second, third ].each { |record| review_post(record, action: "approve") }
  end

  it "lets a visitor search posts and open a permalink that asks them to sign in to react" do
    visit feed_path
    fill_in "Search live shout-outs", with: "Tireless"
    click_button "Search posts"
    expect(page).to have_content(post.message)
    expect(page).to have_no_content(second.message)
    within("#shout_out_#{post.id}") { click_link "Permalink" }
    expect(page).to have_current_path(feed_post_path(post))
    expect(page).to have_link("Fire 0", href: new_ace_session_path)
  end

  it "toggles a fan's reaction on a post" do
    sign_in fan
    visit feed_post_path(post)
    within("#shout_out_#{post.id}") { find('button[aria-label="Fire, 0"]').click }
    expect(page).to have_css('button[aria-label="Fire, 1"][aria-pressed="true"]')
    find('button[aria-label="Fire, 1"]').click
    expect(page).to have_css('button[aria-label="Fire, 0"][aria-pressed="false"]')
  end

  it "keeps a reaction from a team wall on the weekly leaderboard" do
    sign_in fan
    visit team_path(team, side: "feed")
    within("#shout_out_#{post.id}") { find('button[aria-label="Legend, 0"]').click }
    expect(page).to have_css('button[aria-label="Legend, 1"][aria-pressed="true"]')
    click_link "Leaders", match: :first
    expect(page).to have_content(/Most shouted/i)
    expect(page).to have_content("Nico Hoerner")
    expect(page).to have_content("2 shout-outs")
    find("summary", text: "Top shout-out for Nico Hoerner").click
    expect(page).to have_css('button[aria-label="Legend, 1"][aria-pressed="true"]')
  end

  it "uses the fan's saved theme on the leaderboard" do
    fan.update!(theme: "dark")
    sign_in fan
    visit shout_out_leaderboard_path
    expect(page).to have_css('html[data-theme="dark"]')
  end

  it "leaves another fan's reaction free for the author" do
    sign_in fan
    visit feed_post_path(post)
    within("#shout_out_#{post.id}") { find('button[aria-label="Fire, 0"]').click }
    expect(page).to have_css('button[aria-label="Fire, 1"]')
    expect(CreditAccount.for(author).available_cents).to eq(1000 - 500 - 1 - 1)
  end
end
