require "rails_helper"

RSpec.describe "Moderation layout", type: :system do
  let(:author) { create(:ace, username: "wrigley_wes", display_name: "Wes Miller") }
  let(:reviewer) { create(:ace, moderator: true, username: "roster_rae", display_name: "Rae Carter") }
  let!(:quest) { create(:quest, created_by: author, name: "Know every Cubs starter", description: "Name the lineup from the box score.") }

  before do
    sign_in reviewer
    phone_viewport
  end

  it "fits the queue, an item, the decision log, reports, escalations and an ace on a phone" do
    expect_pages_to_fit moderation_path, moderation_item_path(type: "Quest", id: quest.id), moderation_log_path, reports_path,
      escalations_path, ace_profile_path(author)
  end

  it "hides the desktop sidebar on a phone" do
    visit moderation_path
    expect(page).to have_no_css(".shell-sidebar")
  end

  it "keeps the decision log's date filter wide enough to use" do
    visit moderation_log_path
    expect(rect("#" + find_field("From (UTC)")[:id])["width"]).to be >= 200
  end
end
