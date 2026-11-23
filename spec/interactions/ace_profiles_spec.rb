require "rails_helper"

RSpec.describe "Ace identity setup" do

  it "completes existing-account setup, returns to the player and edits identity from the account menu" do
    ace = create(:ace, :without_identity)
    player = create(:player, first_name: "Jalen", last_name: "Brunson")
    visit player_path(player)
    click_link "Sign In", match: :first
    fill_in "Email", with: ace.email
    fill_in "Password", with: "password123"
    within(".account-form") { click_button "Sign in" }
    expect(page).to have_current_path(edit_profile_path)
    expect(page).to have_css("h1", text: /Choose your handle/i)
    find('[aria-label="Account menu"]').click
    within("dialog[open]") { click_button "Dark" }
    expect(page).to have_css('html[data-theme="dark"]')
    fill_in "Handle", with: "Courtside_Tess"
    fill_in "Display name", with: "Tess Moreno"
    choose "Harbor"
    click_button "Save profile"
    expect(page).to have_current_path(player_path(player))
    expect(page).to have_css("h1", text: /Jalen Brunson/i)
    find('[aria-label="Account menu"]').click
    within("dialog[open]") do
      expect(page).to have_content("@courtside_tess")
      expect(page).to have_content("Tess Moreno")
      expect(page).not_to have_content(ace.email)
      click_link "Profile"
    end
    expect(page).to have_css("h1", text: /Your profile/i)
    click_link "Edit profile"
    expect(page).not_to have_field("Handle")
    fill_in "Display name", with: "Tess Rivera"
    choose "Plum"
    click_button "Save profile"
    expect(page).to have_css(".ace-display-name", text: "Tess Rivera")
    expect(page).to have_css(".ace-avatar", text: "TR")
    find('[aria-label="Account menu"]').click
    within("dialog[open]") { click_button "Dark" }
    expect(page).to have_css('html[data-theme="dark"]')
    expect(ace.reload.username).to eq("courtside_tess")
    expect(ace.avatar_color).to eq(Ace::AVATAR_COLORS.fetch("Plum"))
  end

  it "shows duplicate-handle errors and registers a new identity through email confirmation" do
    create(:ace, username: "wrigley_wes")
    visit new_ace_registration_path
    fill_in "Handle", with: "WRIGLEY_WES"
    fill_in "Display name", with: "Wes Rivera"
    fill_in "Email", with: "wes.rivera@example.test"
    fill_in "Password", with: "password123"
    fill_in "Confirm password", with: "password123"
    click_button "Sign up"
    expect(page).to have_css(".account-errors", text: "has already been taken")
    fill_in "Handle", with: "bleacher_wes"
    fill_in "Password", with: "password123"
    fill_in "Confirm password", with: "password123"
    click_button "Sign up"
    expect(page).to have_current_path(new_ace_session_path)
    ace = Ace.find_by! email: "wes.rivera@example.test"
    ace.confirm
    fill_in "Email", with: ace.email
    fill_in "Password", with: "password123"
    within(".account-form") { click_button "Sign in" }
    expect(page).to have_current_path(strength_path)
    find('[aria-label="Account menu"]').click
    expect(page).to have_css("dialog[open]", text: "@bleacher_wes")
  end
end
