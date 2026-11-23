require "rails_helper"

RSpec.describe "Shell search palette" do

  def open_search
    find(".shell-search-toggle").click
    expect(page).to have_css(".shell-search-dialog[open]")
  end

  context "with a player known by a nickname" do
    let!(:player) { create(:player, first_name: "Jalen", last_name: "Brunson", nicknames: [ "Big Body" ]) }

    def search_and_follow
      visit feed_path
      open_search
      fill_in "shell-search-query", with: "Big Body"
      find("#shell-search-query").send_keys(:arrow_down, :enter)
      expect(page).to have_current_path(player_path(player, side: "feed"))
    end

    it "opens from the keyboard with the query focused" do
      visit feed_path
      send_keys [ :control, "k" ]
      expect(page).to have_css(".shell-search-dialog[open]")
      expect(evaluate_script("document.activeElement.id")).to eq("shell-search-query")
    end

    it "finds a player by nickname and opens the selected result on the current side" do
      visit feed_path
      open_search
      fill_in "shell-search-query", with: "Big Body"
      expect(page).to have_css(".search-result", text: "Jalen Brunson")
      find("#shell-search-query").send_keys(:arrow_down)
      expect(page).to have_css('.search-result[aria-selected="true"]', text: "Jalen Brunson")
      find("#shell-search-query").send_keys(:enter)
      expect(page).to have_current_path(player_path(player, side: "feed"))
      expect(page).to have_css('body[data-side="feed"]')
    end

    it "reruns a recent search and closes with Escape" do
      search_and_follow
      open_search
      within(".search-recents") { click_button "Big Body" }
      expect(page).to have_css(".search-result", text: "Jalen Brunson")
      find("#shell-search-query").send_keys(:escape)
      expect(page).to have_no_css(".shell-search-dialog[open]")
    end

    it "clears recent searches" do
      search_and_follow
      open_search
      click_button "Clear recent searches"
      expect(page).to have_no_button("Big Body")
    end
  end

  it "wraps arrow selection and follows a result for visitors and fans" do
    ace = create(:ace)
    knicks = create(:team, territory: "New York", mascot: "Knicks", abbreviation: "NYK")
    create(:team, territory: "New York", mascot: "Nets", abbreviation: "NYN", league: knicks.league)
    visit feed_path
    open_search
    find("#shell-search-query").send_keys(:escape)
    sign_in ace
    visit strength_path
    open_search
    fill_in "shell-search-query", with: "New York"
    expect(page).to have_css(".search-result", count: 2)
    find("#shell-search-query").send_keys(:arrow_up)
    expect(page).to have_css('.search-result[aria-selected="true"]', text: "New York Nets")
    find("#shell-search-query").send_keys(:arrow_down)
    expect(page).to have_css('.search-result[aria-selected="true"]', text: "New York Knicks")
    find("#shell-search-query").send_keys(:escape)
    find('[aria-label="Account menu"]').click
    within("dialog[open]") { click_button "Dark" }
    open_search
    fill_in "shell-search-query", with: "New York"
    expect(page).to have_css(".search-result", count: 2)
    expect(page).to have_css('html[data-theme="dark"]')
    find("#shell-search-query").send_keys(:arrow_down, :enter)
    expect(page).to have_current_path(team_path(knicks, side: "play"))
  end

  it "uses the moderator scope and opens a submitted item for review" do
    author = create(:ace, username: "clutch_sam", display_name: "Sam Carter")
    reviewer = create(:ace, moderator: true)
    quest = create(:quest, created_by: author, name: "Clutch starting five")
    sign_in reviewer
    visit moderation_path
    open_search
    fill_in "shell-search-query", with: "clutch"
    expect(page).to have_css('[aria-label="Queue"]', text: "Clutch starting five")
    expect(page).to have_css('[aria-label="Aces"]', text: "@clutch_sam")
    within(".shell-search-dialog") { click_link "Clutch starting five" }
    expect(page).to have_current_path(moderation_item_path(type: "Quest", id: quest.id))
    expect(page).to have_button("Approve")
  end
end
