require "rails_helper"

RSpec.describe "Admin catalog row selection" do
  let(:team) { create(:team, territory: "Harbor", mascot: "Herons", league: create(:league, name: "Harbor Basketball League", sport: create(:sport, name: "Basketball"))) }
  let(:filtered_path) { admin_catalog_records_path(team_id: team.id, number_on: "2024-06-30") }
  let(:selection_form) { "form[data-controller=catalog-selection]" }
  let!(:players) do
    %w[Jordan_Reed Morgan_Price Avery_Cole Casey_Brooks Taylor_Ellis Cameron_Grant Riley_Hayes Alex_James Drew_King Quinn_Lane Parker_Miles Jamie_Nash Rowan_Owens
      Sage_Perry Reese_Quinn Finley_Ross Logan_Shaw Emerson_Tate Dakota_Vaughn Hayden_Ward Charlie_Young Blake_Zhang Micah_Adams Elliot_Bennett Jesse_Carter Noel_Davis]
      .map { |name| create(:player, first_name: name.split("_").first, last_name: name.split("_").last, team: team) }
  end

  before do
    create(:player, first_name: "Unrelated", last_name: "Athlete")
    sign_in create(:ace, :admin)
    visit filtered_path
  end

  it "enables export once one row is selected and marks the page checkbox mixed" do
    expect(page).to have_button("Export selected CSV", disabled: true)
    expect(page).to have_css('[data-catalog-selection-target="item"]', count: 25)
    check "select_record_#{players.first.id}"
    expect(page).to have_content("1 selected")
    expect(page).to have_button("Export selected CSV", disabled: false)
    expect(evaluate_script('document.querySelector("[data-catalog-selection-target=all]").indeterminate')).to be(true)
  end

  it "selects every row on the displayed page and lets one be removed" do
    check "Select page"
    expect(page).to have_content("25 selected")
    uncheck "select_record_#{players.first.id}"
    expect(page).to have_content("24 selected")
  end

  it "exports the selected rows with the current filter outside Turbo" do
    check "Select page"
    uncheck "select_record_#{players.first.id}"
    form = find(selection_form)
    expect(form[:action]).to end_with(admin_catalog_records_path(format: :csv))
    expect(form[:"data-turbo"]).to eq("false")
    expect(evaluate_script("Object.fromEntries(new FormData(document.querySelector('#{selection_form}')))"))
      .to include("selection" => "selected", "team_id" => team.id.to_s, "kind" => "players", "number_on" => "2024-06-30")
    expect(evaluate_script("new FormData(document.querySelector('#{selection_form}')).getAll('selected_ids[]').length")).to eq(24)
  end

  it "starts each page and record kind with nothing selected" do
    check "Select page"
    visit admin_catalog_records_path(team_id: team.id, number_on: "2024-06-30", page: 2)
    expect(page).to have_css('[data-catalog-selection-target="item"]', count: 1)
    expect(page).to have_content("0 selected")
    visit admin_catalog_records_path(kind: "teams", q: "Herons")
    expect(page).to have_content("0 selected")
    check "select_record_#{team.id}"
    expect(page).to have_content("1 selected")
  end
end
