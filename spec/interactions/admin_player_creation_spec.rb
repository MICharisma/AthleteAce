require "rails_helper"

RSpec.describe "Admin Add player workflow" do
  before do
    create(:sport, name: "Basketball")
    sign_in create(:ace, :admin)
  end

  def add_player
    visit admin_catalog_records_path
    click_link "Add player"
    fill_in "Entity code", with: "PLAYER-JORDAN-REED-1998"
    select "Basketball", from: "Sport"
    fill_in "First name", with: "Jordan"
    fill_in "Last name", with: "Reed"
    fill_in "Current position", with: "Guard"
    click_button "Create player"
  end

  it "creates a player without a team, then asks why" do
    add_player
    expect(page).to have_content("Player created. Why did you make this change?")
    expect(page).to have_content("Created a new player")
    player = Player.find(CatalogEdit.sole.record_id)
    expect(player.team).to be_nil
    expect(player.entity_code).to eq("PLAYER-JORDAN-REED-1998")
  end

  it "finds the new player by entity code" do
    add_player
    click_link "Skip for now"
    fill_in "Search players", with: "PLAYER-JORDAN-REED-1998"
    click_button "Filter sports data"
    click_link "Jordan Reed"
    expect(page).to have_field("Current position", with: "Guard")
  end

  it "explains the addition later from the correction history" do
    add_player
    edit = CatalogEdit.sole
    visit admin_catalog_edits_path
    click_link "Jordan Reed · Edit ##{edit.id}"
    fill_in "Why did you make this change?", with: "Added from the club's published roster."
    click_button "Save reason"
    expect(page).to have_content("Reason saved.")
    expect(edit.reload.reason).to eq("Added from the club's published roster.")
  end
end
