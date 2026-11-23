require "rails_helper"

RSpec.describe "Redesign completion" do

  it "skips the shell with the keyboard on every side" do
    sign_in create(:ace, :admin, username: "morgan_lane", display_name: "Morgan Lane")
    [ strength_path, feed_path, moderation_path, admin_path ].each do |path|
      visit path
      expect(page).to have_css('html[lang="en"]')
      send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.textContent")).to eq("Skip to content")
      send_keys(:enter)
      expect(page).to have_css("#main-content:focus")
      expect(page).to have_current_path(path)
    end
  end

  it "recovers from an empty Feed search and keeps the signed-out personal view clear" do
    author = create(:ace, username: "avery_reyes", display_name: "Avery Reyes")
    player = create(:player, first_name: "Jordan", last_name: "Reyes")
    buy_credit author
    post = submit_credit(ace: author, target: player, message: "Always makes the extra pass.", bid: 100)
    review_post post, action: "approve"
    visit feed_path
    fill_in "Search live shout-outs", with: "backcourt"
    click_button "Search posts"
    expect(page).to have_css(".shell-empty h2", text: "No matching shout-outs.")
    expect(page).not_to have_content("No shout-outs yet.")
    click_link "Reset view"
    expect(page).to have_field("Search live shout-outs", with: "")
    expect(page).to have_css(".shout-out-card", text: post.message)
    visit feed_path(view: "my_teams")
    expect(page).to have_content(/Find your teams here/i)
    expect(page).not_to have_content("No shout-outs yet.")
    expect(page).to have_link("Sign in")
  end

  it "clears leaderboard sports filters while keeping the selected week and target kind" do
    league = create(:league, name: "National Basketball Association")
    week = Date.current.beginning_of_week - 7
    visit shout_out_leaderboard_path(kind: "teams", week: week.iso8601, league_id: league.id, sport_id: league.sport_id)
    expect(page).to have_content("No live shout-outs for this week.")
    click_link "Clear filters"
    expect(page).to have_select("Sport", selected: "All sports")
    expect(page).to have_select("League", selected: "All leagues")
    expect(page).to have_field("Week containing", with: week.iso8601)
    expect(page).to have_css('[aria-label="Leaderboard targets"] a[aria-current="page"]', text: "Teams")
    expect(page).not_to have_link("Clear filters")
  end

  it "labels section headings for Feed, Moderate and Admin while retaining public Browse headings" do
    sign_in create(:ace, :admin, username: "roster_rae", display_name: "Rae Carter")
    [ new_shout_out_draft_path, shout_out_drafts_path, shout_outs_path, wallet_path, shout_out_leaderboard_path ].each do |path|
      visit path
      expect(page).to have_css(".browse-header .eyebrow", text: /\AFeed\z/i)
    end
    visit reports_path
    expect(page).to have_css(".browse-header .eyebrow", text: /\AModerate\z/i)
    visit shout_out_revenue_path
    expect(page).to have_css(".browse-header .eyebrow", text: /\AAdmin\z/i)
    team = create(:team, territory: "Portland", mascot: "Trail Blazers")
    visit league_path(team.league, side: "feed")
    expect(page).to have_css(".browse-header .eyebrow", text: /\ABrowse\z/i)
    expect(page).to have_css('body[data-side="feed"]')
  end
end
