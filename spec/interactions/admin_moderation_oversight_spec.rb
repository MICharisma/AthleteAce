require "rails_helper"

RSpec.describe "Admin moderation oversight workflow" do

  let(:admin) { create :ace, :admin, username: "morgan_lee", display_name: "Morgan Lee" }

  before do
    now = Time.current.utc
    reviewer = create :ace, moderator: true, username: "roster_rae", display_name: "Rae Carter"
    author = create :ace, username: "june_morris", display_name: "June Morris"
    quest = spectrum = nil
    travel_to(now - 2.days) do
      quest = create :quest, name: "Learn the Northern backcourt", created_by: author
      spectrum = create :spectrum, name: "Composure", created_by: author
    end
    travel_to(now - 2.days + 1.hour) { Moderation::Review.call(record: quest, actor: reviewer, action: "approve", revision: 1, status: "pending") }
    travel_to(now - 2.days + 3.hours) { Moderation::Review.call(record: spectrum, actor: reviewer, action: "reject", revision: 1, status: "pending", reason: "Clarify the scale endpoints.") }
    travel_to(now - 1.day) { Moderation::Review.call(record: quest, actor: reviewer, action: "hide", revision: 1, status: "approved", reason: "The roster needs another check.") }
    travel_to(now - 1.day + 1.hour) { Moderation::Review.call(record: quest, actor: reviewer, action: "reopen", revision: 1, status: "hidden") }
    travel_to(now - 1.day + 2.hours) { Moderation::Review.call(record: quest, actor: reviewer, action: "approve", revision: 1, status: "pending") }
    create :quest, name: "Reference roster collection"
    sign_in admin
  end

  it "summarizes recorded decisions and reversals from the admin overview" do
    visit admin_path
    click_link "Moderation oversight"
    expect(page).to have_current_path(admin_moderation_oversight_path)
    expect(page).to have_css('[data-oversight="total"]', text: "5")
    expect(page).to have_css('[data-oversight="changes"]', text: "2")
    expect(page).to have_content("3 of 3 decision pairs matched.")
    expect(page).to have_content("Formal appeals are not linked to original decisions")
  end

  it "narrows the metrics to one content type" do
    visit admin_moderation_oversight_path
    select "Quests", from: "Content type"
    click_button "Apply filters"
    expect(page).to have_css('[data-oversight="total"]', text: "4")
  end

  it "opens a metric's matching decisions in the moderation log with exportable filters" do
    visit admin_moderation_oversight_path
    select "Quests", from: "Content type"
    click_button "Apply filters"
    find('a[aria-label="Quests approved: 2 events"]').click
    expect(page).to have_css('body[data-side="mod"]')
    expect(page).to have_checked_field("Review transitions only")
    expect(page).to have_select("Content type", selected: "Quest")
    expect(page).to have_select("Action", selected: "Approved")
    expect(page).to have_css(".moderation-list .moderation-row", count: 2)
    expect(page).to have_no_content("Reference roster collection")
    query = Rack::Utils.parse_nested_query(URI.parse(find_link("Export CSV")[:href]).query)
    expect(query).to include("reviews_only" => "1", "item_type" => "Quest", "decision_action" => "approved")
  end
end
