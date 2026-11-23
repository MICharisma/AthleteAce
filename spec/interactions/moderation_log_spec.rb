require "rails_helper"

RSpec.describe "Moderation decision history" do
  let(:author) { create(:ace, username: "wrigley_wes", display_name: "Wes Miller") }
  let(:reviewer) { create(:ace, moderator: true, username: "roster_rae", display_name: "Rae Carter") }

  before do
    Moderation::Review.call(record: create(:quest, created_by: author, name: "Know every Cubs starter"), actor: reviewer, action: "approve", revision: 1, status: "pending", reason: "A clear roster goal.")
    Moderation::Review.call(record: create(:spectrum, created_by: author, name: "Court vision"), actor: reviewer, action: "reject", revision: 1, status: "pending", reason: "Clarify the scale endpoints.")
    sign_in reviewer
    visit moderation_log_path
  end

  def filter_to_approved_quests
    select "Quest", from: "Content type"
    select "Approved", from: "Action"
    select reviewer.handle, from: "Recorded actor"
    click_button "Apply filters"
  end

  it "lists every recorded decision with its reason" do
    expect(page).to have_content("A clear roster goal.")
    expect(page).to have_content("Clarify the scale endpoints.")
  end

  it "filters by type, action and actor, and totals what matches" do
    filter_to_approved_quests
    expect(page).to have_content("A clear roster goal.")
    expect(page).to have_no_content("Clarify the scale endpoints.")
    within('[aria-label="Decision totals"]') do
      expect(page).to have_content(/Recorded events\s+1/i)
      expect(page).to have_content(/Approved\s+1/i)
    end
  end

  it "keeps the filters in the form and the export link" do
    filter_to_approved_quests
    expect(page).to have_select("Content type", selected: "Quest")
    query = Rack::Utils.parse_nested_query(URI.parse(find_link("Export CSV")[:href]).query)
    expect(query).to include("item_type" => "Quest", "decision_action" => "approved", "actor_id" => reviewer.id.to_s)
  end

  it "clears the filters" do
    filter_to_approved_quests
    click_link "Clear filters"
    expect(page).to have_select("Content type", selected: "All types")
    expect(page).to have_content("Clarify the scale endpoints.")
  end

  it "says when no decision matches" do
    select "Hidden", from: "Action"
    click_button "Apply filters"
    expect(page).to have_content("No decisions match.")
  end
end
