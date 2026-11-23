require "rails_helper"

RSpec.describe "Escalation handoffs" do
  it "hands content to an admin, preserves private context, and closes an account handoff" do
    author = create(:ace, username: "wrigley_wes", display_name: "Wes Miller")
    reviewer = create(:ace, moderator: true, display_name: "Rae Carter")
    admin = create(:ace, :admin, display_name: "Jordan Lee")
    quest = create(:quest, created_by: author, name: "Know every Cubs starter")
    sign_in reviewer
    visit moderation_item_path(type: "Quest", id: quest.id)
    find("summary", text: /Escalate to admin/i).click
    fill_in "Escalation reason", with: "Check whether this overlaps the roster quest."
    click_button "Escalate to admin"
    expect(page).to have_content("Escalated to admin.")
    expect(page).not_to have_button("Resolve escalation")
    visit moderation_path
    expect(page).not_to have_content(quest.name)
    sign_out reviewer
    sign_in admin
    visit escalations_path
    click_link quest.name
    expect(page).to have_content("Check whether this overlaps the roster quest.")
    select "Approve", from: "Resolution"
    fill_in "Resolution reason", with: "A distinct learning goal."
    click_button "Resolve escalation"
    expect(page).to have_content("Escalation resolved.")
    expect(quest.reload).to be_approved
    expect(page).not_to have_button("Resolve escalation")
    sign_out admin
    sign_in reviewer
    visit ace_profile_path(author)
    find("summary", text: /Escalate to admin/i).click
    fill_in "Escalation reason", with: "Discuss this account's recent proposals."
    click_button "Escalate to admin"
    expect(page).to have_content("Escalated to admin.")
    account_case = ModerationEscalation.find_by!(subject: author)
    expect(page).to have_current_path(escalation_path(account_case))
    sign_out reviewer
    sign_in admin
    visit escalation_path(account_case)
    expect(page).to have_content("without changing account permissions")
    fill_in "Resolution reason", with: "Reviewed. No account action needed."
    click_button "Resolve escalation"
    expect(page).to have_content("Reviewed. No account action needed.")
    sign_out admin
    sign_in author
    visit quest_path(quest)
    expect(page).to have_css("h1", text: /Know every Cubs starter/i)
    expect(page).not_to have_content("Check whether this overlaps")
    visit posting_status_path
    expect(page).not_to have_content("Discuss this account")
  end
end
