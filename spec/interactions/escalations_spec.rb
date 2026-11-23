require "rails_helper"

RSpec.describe "Escalation handoffs" do
  let(:author) { create(:ace, username: "wrigley_wes", display_name: "Wes Miller") }
  let(:reviewer) { create(:ace, moderator: true, display_name: "Rae Carter") }
  let(:admin) { create(:ace, :admin, display_name: "Jordan Lee") }
  let(:quest) { create(:quest, created_by: author, name: "Know every Cubs starter") }

  def escalate(subject, reason)
    Moderation::Escalate.call(subject: subject, actor: reviewer, reason: reason, request_key: SecureRandom.uuid,
      **(subject.is_a?(Ace) ? {} : { revision: subject.moderation_revision, status: subject.moderation_status }))
  end

  it "hands a submission to an admin and takes it out of the reviewer's queue" do
    sign_in reviewer
    visit moderation_item_path(type: "Quest", id: quest.id)
    find("summary", text: /Escalate to admin/i).click
    fill_in "Escalation reason", with: "Check whether this overlaps the roster quest."
    click_button "Escalate to admin"
    expect(page).to have_content("Escalated to admin.")
    expect(page).to have_no_button("Resolve escalation")
    visit moderation_path
    expect(page).to have_no_content(quest.name)
  end

  it "lets an admin resolve a submission's escalation with a decision" do
    escalate quest, "Check whether this overlaps the roster quest."
    sign_in admin
    visit escalations_path
    click_link quest.name
    expect(page).to have_content("Check whether this overlaps the roster quest.")
    select "Approve", from: "Resolution"
    fill_in "Resolution reason", with: "A distinct learning goal."
    click_button "Resolve escalation"
    expect(page).to have_content("Escalation resolved.")
    expect(page).to have_no_button("Resolve escalation")
    expect(quest.reload).to be_approved
  end

  it "hands an account to an admin and opens its case" do
    sign_in reviewer
    visit ace_profile_path(author)
    find("summary", text: /Escalate to admin/i).click
    fill_in "Escalation reason", with: "Discuss this account's recent proposals."
    click_button "Escalate to admin"
    expect(page).to have_content("Escalated to admin.")
    expect(page).to have_current_path(escalation_path(ModerationEscalation.find_by!(subject: author)))
  end

  it "lets an admin close an account case without changing permissions" do
    account_case = escalate(author, "Discuss this account's recent proposals.")
    sign_in admin
    visit escalation_path(account_case)
    expect(page).to have_content("without changing account permissions")
    fill_in "Resolution reason", with: "Reviewed. No account action needed."
    click_button "Resolve escalation"
    expect(page).to have_content("Reviewed. No account action needed.")
  end

  it "keeps escalation reasons private from the author" do
    escalate quest, "Check whether this overlaps the roster quest."
    escalate author, "Discuss this account's recent proposals."
    sign_in author
    visit quest_path(quest)
    expect(page).to have_css("h1", text: /Know every Cubs starter/i)
    expect(page).to have_no_content("Check whether this overlaps")
    visit posting_status_path
    expect(page).to have_no_content("Discuss this account")
  end
end
