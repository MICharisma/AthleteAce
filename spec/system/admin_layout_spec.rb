require "rails_helper"

RSpec.describe "Admin layout", type: :system do
  let(:admin) { create(:ace, :admin, username: "front_office", display_name: "Dana Whitfield") }
  let(:team) { create(:team, territory: "New York", mascot: "Knicks", abbreviation: "NYK") }
  let!(:player) { create(:player, first_name: "Jalen", last_name: "Brunson", team: team, current_position: "PG", active: true) }

  before do
    create(:ace, username: "wrigley_wes", display_name: "Wes Miller")
    create(:quest, name: "Know every Knicks starter")
    sign_in admin
    phone_viewport
  end

  it "fits the admin overview, people, catalogs and money pages on a phone" do
    expect_pages_to_fit admin_path, admin_people_path, admin_catalog_records_path, admin_catalog_records_path(kind: "teams"),
      admin_content_catalog_path, admin_moderation_oversight_path, shout_out_revenue_path
  end
end
