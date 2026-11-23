require "rails_helper"

RSpec.describe "Live Feed" do
  let(:author) { create(:ace) }
  let(:fan) { create(:ace) }
  let(:mlb) { create(:mlb, sport: create(:baseball)) }
  let(:nba) { create(:nba, sport: create(:basketball)) }
  let(:cubs) { create(:team, league: mlb, territory: "Chicago", mascot: "Cubs") }
  let(:bulls) { create(:team, league: nba, territory: "Chicago", mascot: "Bulls") }
  let(:fan_path) { feed_path(sport_id: mlb.sport_id, league_id: mlb.id, q: "hustle") }
  let(:first) { submit_credit(ace: author, target: cubs, message: "Cubs hustle never stops", bid: 500) }
  let(:second) { submit_credit(ace: author, target: cubs, message: "Cubs hustle through every inning", bid: 100) }
  let(:incoming) { submit_credit(ace: author, target: cubs, message: "Cubs hustle wins again", bid: 100) }
  let(:pending_post) { submit_credit(ace: author, target: cubs, message: "A thought still in review", bid: 100) }
  let(:other_league) { submit_credit(ace: author, target: bulls, message: "Bulls hustle on the court", bid: 100) }

  before do
    buy_credit(author, amount: 2000)
    [ first, second, incoming, pending_post, other_league ] # Submitted in this order.
    [ first, second ].each { |post| review_post(post, action: "approve") }
    second.shout_out_reactions.create!(ace: fan, kind: "fire")
  end

  def visit_as_fan
    sign_in fan
    visit fan_path
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
  end

  def post_order = all('article[id^="shout_out_"]').map { |node| node[:id] }

  it "shows the author their pending post and other fans only approved posts" do
    sign_in author
    visit feed_path(sport_id: mlb.sport_id)
    expect(page).to have_content(pending_post.message)
    expect(page).to have_no_content(other_league.message)

    visit_as_fan
    expect(page).to have_content(first.message)
    expect(page).to have_no_content(pending_post.message)
  end

  it "keeps an unfinished search and filter when a refresh arrives" do
    visit_as_fan
    order = post_order
    execute_script('document.addEventListener("turbo:morph", () => document.documentElement.dataset.refreshed = "yes")')
    fill_in "Search live shout-outs", with: "An unfinished search"
    select nba.sport.name, from: "Sport"
    review_post(other_league, action: "approve")
    expect(page).to have_css('html[data-refreshed="yes"]')
    expect(page).to have_field("Search live shout-outs", with: "An unfinished search")
    expect(page).to have_select("Sport", selected: nba.sport.name)
    expect(page).to have_current_path(fan_path)
    expect(page).to have_no_content(other_league.message)
    expect(post_order).to eq(order)
  end

  it "adds a newly approved post without reordering the posts already shown" do
    visit_as_fan
    order = post_order
    review_post(incoming, action: "approve")
    expect(page).to have_content(incoming.message)
    expect(post_order & order).to eq(order)
    expect(page).to have_no_content(pending_post.message)
  end

  it "removes a hidden post for every visitor" do
    using_session(:author) do
      sign_in author
      visit feed_path(sport_id: mlb.sport_id)
    end
    visit_as_fan
    review_post(first, action: "hide")
    expect(page).to have_no_css("#shout_out_#{first.id}")
    expect(page).to have_content(second.message)
    using_session(:author) do
      expect(page).to have_no_css("#shout_out_#{first.id}")
      expect(page).to have_content(pending_post.message)
    end
  end

  it "keeps each visitor's own reactions through a refresh" do
    using_session(:author) do
      sign_in author
      visit feed_path(sport_id: mlb.sport_id)
    end
    visit_as_fan
    review_post(incoming, action: "approve")
    within("#shout_out_#{second.id}") { expect(page).to have_css('button[aria-label="Fire, 1"][aria-pressed="true"]') }
    using_session(:author) do
      expect(page).to have_content(incoming.message)
      within("#shout_out_#{second.id}") { expect(page).to have_css('button[aria-label="Fire, 1"][aria-pressed="false"]') }
    end
  end
end
