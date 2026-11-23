require "rails_helper"

RSpec.describe "Navigation" do

  def open_menu(label = "Account menu")
    expect(page).to have_css('[data-controller~="shell"]') {
      page.evaluate_script("!document.documentElement.hasAttribute('data-turbo-preview') && Boolean(window.Stimulus?.getControllerForElementAndIdentifier(document.querySelector('[data-controller~=shell]'), 'shell'))")
    }
    find("button[aria-label='#{label}']").click
    expect(page).to have_css("dialog[open]")
  end

  it "opens Feed for visitors and offers Play preview and sign-in" do
    visit root_path
    expect(page).to have_current_path(feed_path)
    within('[aria-label="Switch sides"]') do
      expect(page).to have_link("Play")
      expect(page).to have_link("Feed")
      expect(page).not_to have_link("Moderate")
      expect(page).not_to have_link("Admin")
      expect(page).to have_content(/preview/i)
    end
    expect(page).to have_link("Sign In")
    expect(page).not_to have_link("Sign Up")
    within('[aria-label="Switch sides"]') { click_link "Play" }
    expect(page).to have_current_path(strength_path)
    within('[aria-label="Play navigation"]') { click_link "Browse" }
    expect(page).to have_css("h1", text: /browse/i)
    within("#browse-sports") do
      expect(page).to have_link("Sports")
      click_link "Teams"
    end
    expect(page).to have_current_path(teams_path)
    expect(page).to have_css('body[data-side="play"]')
  end

  it "saves a visitor's appearance without an account" do
    visit feed_path
    open_menu "Appearance"
    expect(page).to have_css("dialog[open]")
    within("dialog[open]") { click_button "Dark" }
    expect(page).to have_css('html[data-theme="dark"]')
    page.refresh
    expect(page).to have_css('html[data-theme="dark"]')
    open_menu "Appearance"
    within("dialog[open]") { click_button "System" }
    expect(page).to have_css('html[data-theme="system"]')
  end

  context "for a signed-in fan" do
    let(:ace) { create(:ace, email: "tess.moreno@example.test") }

    before { sign_in ace }

    it "lands on Play with five tabs" do
      visit root_path
      expect(page).to have_current_path(strength_path)
      within('[aria-label="Play navigation mobile"]') { expect(all("a").map(&:text)).to eq(%w[Home Games Quests History Browse]) }
    end

    it "opens an account sheet that returns focus to its button when closed" do
      visit strength_path
      open_menu
      expect(page).to have_css("dialog[open]", text: ace.handle)
      within("dialog[open]") do
        expect(page).to have_link("My ratings")
        expect(page).to have_link("Settings")
        expect(page).to have_link("Begin Quest")
      end
      # The browser closes a modal dialog on Escape; the app returns focus.
      execute_script("document.querySelector('dialog[open]').close()")
      expect(page).to have_no_css("dialog[open]")
      expect(evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Account menu")
    end

    it "saves a chosen theme to the account and keeps it across pages" do
      visit strength_path
      open_menu
      within("dialog[open]") { click_button "Dark" }
      expect(page).to have_css('html[data-theme="dark"]')
      expect(ace.reload.theme).to eq("dark")
      within('[aria-label="Play navigation mobile"]') { click_link "Browse" }
      expect(page).to have_css('html[data-theme="dark"]')
    end

    it "signs out to Feed with the system theme" do
      ace.update!(theme: "dark")
      visit strength_path
      open_menu
      within("dialog[open]") { click_button "Sign Out" }
      expect(page).to have_link("Sign In")
      expect(page).to have_current_path(feed_path)
      expect(page).to have_css('html[data-theme="system"]')
    end
  end

  it "keeps the moderation side on shared pages and exposes its queue and log" do
    reviewer = create(:ace, moderator: true, email: "sam.carter@example.test")
    player = create(:player, first_name: "Jalen", last_name: "Brunson")
    create(:quest, created_by: create(:ace), name: "Learn the Knicks starting five")
    sign_in reviewer
    visit moderation_path
    expect(page).to have_css(".shell-sidebar")
    visit player_path(player)
    expect(page).to have_css('body[data-side="mod"]')
    within('[aria-label="Switch sides"]') { click_link "Play" }
    expect(page).to have_current_path(strength_path)
    visit player_path(player)
    expect(page).to have_css('body[data-side="play"]')
    within('[aria-label="Switch sides"]') { click_link "Moderate" }
    within('[aria-label="Moderate navigation mobile"]') { click_link "Decision log" }
    expect(page).to have_current_path(moderation_log_path)
  end

  it "provides admin catalog navigation and remembers the Admin side" do
    sign_in create(:ace, :admin, email: "alex.rivera@example.test")
    visit root_path
    expect(page).to have_current_path(admin_path)
    within('[aria-label="Switch sides"]') { expect(all("a").size).to eq(4) }
    within(".shell-sidebar") { click_link "Sports data" }
    click_link "Other sports data"
    within("#browse-sports") { click_link "Teams" }
    expect(page).to have_css('body[data-side="admin"]')
    within('[aria-label="Admin navigation mobile"]') { click_link "Content catalog" }
    expect(page).to have_current_path(admin_content_catalog_path)
    expect(page).to have_content("Manage quests, achievements, and rating spectrums.")
    expect(page).to have_css('body[data-side="admin"]')
  end

  it "keeps quest discovery reachable through the account menu" do
    sign_in create(:ace)
    create_list(:quest, 3)
    visit root_path
    open_menu
    within("dialog[open]") { click_link "Begin Quest" }
    expect(page).to have_content("Quest Discovery")
    expect(page).to have_button("Begin Quest")
    expect(page).to have_link("Next Quest")
    expect(page).not_to have_css("dialog[open]")
  end

  it "lets a visitor continue with Google immediately after signing out from Feed" do
    ace = create(:ace, email: "google.visitor@example.test", google_uid: "google-uid-nav-1")
    previous_mode = OmniAuth.config.test_mode
    previous_auth = OmniAuth.config.mock_auth[:google_oauth2]
    allow(Rails.application.config.x.google_oauth).to receive(:enabled).and_return(true)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: ace.google_uid,
      info: { email: ace.email, email_verified: true, name: ace.display_name }
    )

    sign_in ace
    visit feed_path
    open_menu
    within("dialog[open]") { click_button "Sign Out" }

    expect(page).to have_current_path(feed_path)
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_css('button[aria-label="Appearance"][aria-expanded="false"]')
    expect(page).to have_css("button.google-sign-in")

    find("button.google-sign-in").click
    expect(page).to have_css('button[aria-label="Account menu"]')
  ensure
    OmniAuth.config.test_mode = previous_mode
    OmniAuth.config.mock_auth[:google_oauth2] = previous_auth
  end
end
