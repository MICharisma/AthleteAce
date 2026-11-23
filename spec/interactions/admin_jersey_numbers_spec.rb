require "rails_helper"

RSpec.describe "Admin dated jersey workflow" do

  it "selects a date and follows a string number to assignment history" do
    admin = create(:ace, :admin, theme: "light")
    team = create(:team, territory: "Harbor", mascot: "Herons")
    player = create(:player, first_name: "Jordan", last_name: "Reed", team: team)
    JerseyNumberAssignment.create!(player: player, team: team, number: "00", start_date: Date.new(2024, 1, 1), end_date: Date.new(2024, 6, 30), entity_code: "HBL:NUMBER:REED:00")
    JerseyNumberAssignment.create!(player: player, team: team, number: "7", start_date: Date.new(2024, 7, 1))
    sign_in admin
    visit admin_catalog_records_path(q: "Jordan", number_on: "2024-06-30")
    expect(page).to have_field("Number on date", with: "2024-06-30")
    expect(page).to have_link("00", href: admin_player_history_path(player, tab: "numbers"))
    export = find_link("Export filtered CSV")
    expect(Rack::Utils.parse_query(URI.parse(export[:href]).query)["number_on"]).to eq("2024-06-30")
    click_link "00"
    expect(page).to have_content("Number assignments (2)")
    expect(page).to have_content("HBL:NUMBER:REED:00")
    expect(page).to have_content("Open end")
    expect(page).to have_content("2024-06-30")
  end
end
