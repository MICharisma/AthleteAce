require "rails_helper"

RSpec.describe "Admin People workflow" do
  let(:admin) { create(:ace, :admin, username: "roster_rae", display_name: "Rae Carter") }
  let(:ace) { create(:ace, username: "wrigley_wes", display_name: "Wes Miller") }

  before do
    SignInEvent.create!(ace: ace, outcome: "success", ip_address: "192.0.2.14", user_agent: "Firefox on macOS")
    sign_in admin
  end

  def confirm_action(reason)
    fill_in "Action reason", with: reason
    fill_in "Your current password", with: "password123"
  end

  it "finds an ace by handle and shows their sign-in history" do
    visit admin_people_path
    fill_in "Search aces", with: "wrigley_wes"
    click_button "Filter people"
    expect(page).to have_no_content(admin.email)
    click_link "Wes Miller"
    expect(page).to have_content("Firefox on macOS")
    expect(page).to have_content("192.0.2.14")
  end

  it "changes a role with a recorded reason" do
    visit admin_person_path(ace)
    select "Moderator", from: "Role"
    confirm_action "Review roster proposals."
    click_button "Save role"
    expect(page).to have_content("Account action recorded.")
    expect(page).to have_content("Review roster proposals.")
    expect(ace.reload.role).to eq("moderator")
  end

  it "suspends and reactivates an account" do
    visit admin_person_path(ace)
    confirm_action "Pause sign-in during account review."
    click_button "Suspend account"
    expect(page).to have_content("Account action recorded.")
    expect(ace.reload).to be_suspended
    confirm_action "Account review complete."
    click_button "Reactivate account"
    expect(page).to have_content("Account review complete.")
    expect(ace.reload).not_to be_suspended
  end

  it "links to the moderator view, which leaves out sign-in details" do
    visit admin_person_path(ace)
    click_link "View as moderator"
    expect(page).to have_current_path(ace_profile_path(ace, side: "mod"))
    expect(page).to have_content("Wes Miller")
    expect(page).to have_no_content("Firefox on macOS")
  end
end
