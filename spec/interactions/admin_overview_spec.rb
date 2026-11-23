require "rails_helper"

RSpec.describe "Admin operational overview" do

  it "shows recorded cash, reviews and a case link" do
    admin = create(:ace, :admin, display_name: "Rae Carter", theme: "light")
    reviewer = create(:ace, moderator: true, display_name: "Morgan Price")
    author = create(:ace)
    buy_credit(author, amount: 1234)
    post = submit_credit(ace: author, target: create(:player), bid: 250)
    review_post(post, action: "approve", reviewer: reviewer)
    quest = create(:quest, created_by: author, name: "Learn the New York roster")
    escalation = Moderation::Escalate.call(subject: quest, actor: reviewer, reason: "Needs another review",
      request_key: SecureRandom.uuid, revision: quest.moderation_revision, status: quest.moderation_status)
    sign_in admin
    visit admin_path
    expect(page).to have_css('[data-overview="cash"]', text: "$12.34")
    expect(page).to have_css('[data-overview="reviews"]', text: "1")
    expect(page).to have_css('[data-overview="escalations"]', text: "1")
    expect(page).to have_css("[data-cash-date]", count: 14)
    expect(page).to have_link("View case", href: escalation_path(escalation))
    click_link "View case"
    expect(page).to have_current_path(escalation_path(escalation))
    expect(page).to have_content("Learn the New York roster")
    expect(page).to have_content("Needs another review")
  end
end
