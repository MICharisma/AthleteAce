require "rails_helper"

RSpec.describe "Admin Add player workflow" do

  it "creates first, explains the exact addition later and returns to the audited profile" do
    admin = create(:ace, :admin, theme: "light")
    create(:sport, name: "Basketball")
    sign_in admin
    visit admin_catalog_records_path
    click_link "Add player"
    fill_in "Entity code", with: "PLAYER-JORDAN-REED-1998"
    select "Basketball", from: "Sport"
    fill_in "First name", with: "Jordan"
    fill_in "Last name", with: "Reed"
    fill_in "Current position", with: "Guard"
    click_button "Create player"
    expect(page).to have_content("Player created. Why did you make this change?")
    expect(page).to have_content("Created a new player")
    edit = CatalogEdit.sole
    player = Player.find(edit.record_id)
    expect(player.team).to be_nil
    expect(player.entity_code).to eq("PLAYER-JORDAN-REED-1998")
    click_link "Skip for now"
    fill_in "Search players", with: player.entity_code
    click_button "Filter sports data"
    click_link "Jordan Reed"
    expect(page).to have_field("Current position", with: "Guard")
    click_link "All correction history"
    click_link "Jordan Reed · Edit ##{edit.id}"
    fill_in "Why did you make this change?", with: "Added from the club's published roster."
    click_button "Save reason"
    expect(page).to have_content("Reason saved.")
    expect(edit.reload.reason).to eq("Added from the club's published roster.")
  end
end
