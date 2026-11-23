require "rails_helper"

RSpec.describe "Admin sports data workflow" do
  let(:team) { create(:team, territory: "New York", mascot: "Knicks", abbreviation: "NYK", primary_color: "#006BB6", secondary_color: "#F58426") }
  let!(:player) { create(:player, first_name: "Jalen", last_name: "Brunson", entity_code: "AA:PLAYER:BRUNSON", team: team, current_position: "PG", active: true) }

  before { sign_in create(:ace, :admin, username: "roster_rae", display_name: "Rae Carter") }

  def rename_player
    visit edit_admin_catalog_record_path(player, kind: "players")
    fill_in "First name", with: "Jalen Marquis"
    click_button "Save changes"
  end

  it "filters players and exports the same filter" do
    visit admin_catalog_records_path
    fill_in "Search players", with: "Jalen"
    click_button "Filter sports data"
    expect(page).to have_current_path(/q=Jalen/)
    expect(page).to have_content("Jalen Brunson")
    export = URI.parse(find_link("Export filtered CSV")[:href])
    expect(export.path).to eq(admin_catalog_records_path(format: :csv))
    expect(Rack::Utils.parse_query(export.query)).to include("q" => "Jalen", "kind" => "players")
  end

  it "saves an edit first, then asks why and shows the change" do
    rename_player
    expect(page).to have_content("Saved. Why did you make this change?")
    expect(page).to have_content("Before")
    expect(page).to have_content("After")
    expect(player.reload.first_name).to eq("Jalen Marquis")
  end

  it "lists a skipped reason in the correction history" do
    rename_player
    click_link "Skip for now"
    expect(CatalogEdit.sole.reason).to be_nil
    click_link "Correction history"
    expect(page).to have_content("Reason not supplied")
  end

  it "explains an earlier edit from the correction history" do
    rename_player
    edit = CatalogEdit.sole
    visit admin_catalog_edits_path
    click_link "Jalen Brunson · Edit ##{edit.id}"
    expect(page).to have_current_path(admin_catalog_edit_path(edit))
    fill_in "Why did you make this change?", with: "The roster gives his full first name."
    click_button "Save reason"
    expect(page).to have_content("Reason saved.")
    expect(edit.reload.reason).to eq("The roster gives his full first name.")
  end

  it "picks a readable text color for a team's new primary color" do
    visit admin_catalog_records_path(kind: "teams")
    click_link "New York Knicks"
    fill_in "Primary color", with: "#FFFFFF"
    click_button "Save changes"
    expect(page).to have_content("Text color")
    expect(page).to have_content(TeamPalette::DARK_TEXT)
  end
end
