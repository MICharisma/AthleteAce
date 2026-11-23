require "rails_helper"

RSpec.describe "Moderation queue" do
  it "shows pending content and records a review" do
    author = create(:ace)
    reviewer = create(:ace, moderator: true)
    quest = create(:quest, created_by: author, name: "Know the starting lineup", description: "Learn the players on this season's roster.")
    create(:spectrum, created_by: author, name: "Court vision")
    sign_in reviewer
    visit moderation_path
    expect(page).to have_link("Moderate")
    expect(page).to have_content("Court vision")
    click_link "Know the starting lineup"
    expect(page).to have_button("Approve")
    fill_in "Reason or note", with: "A clear learning quest."
    click_button "Approve"
    expect(page).to have_content("Decision recorded.")
    expect(page).to have_button("Hide")
    expect(quest.reload).to be_approved
    click_link "Back to queue"
    expect(page).not_to have_content("Know the starting lineup")
    click_link "Decision log", match: :first
    expect(page).to have_content("A clear learning quest.")
  end

  it "moves through the filtered queue with shortcuts and ignores keys while typing a reason" do
    author = create(:ace)
    reviewer = create(:ace, moderator: true)
    first = create(:quest, created_by: author, name: "First queue quest")
    second = create(:quest, created_by: author, name: "Second queue quest")
    create(:spectrum, created_by: author, name: "Other content")
    sign_in reviewer
    visit moderation_path
    click_link "Quests 2"
    expect(page).not_to have_content("Other content")
    send_keys("j")
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Review First queue quest")
    send_keys("j")
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Review Second queue quest")
    send_keys("k", :enter)
    expect(page).to have_css("h1", text: /First queue quest/i)
    send_keys("j")
    expect(page).to have_css("h1", text: /Second queue quest/i)
    expect(page).to have_content("2 of 2 · Quests · pending")
    send_keys("k")
    expect(page).to have_css("h1", text: /First queue quest/i)
    send_keys("?")
    expect(page).to have_content("Shortcuts pause while you type in a field.")
    send_keys("r")
    expect(page.evaluate_script("document.activeElement.id")).to eq("reason")
    send_keys("a useful learning quest", :enter)
    expect(page).to have_field("Reason or note", with: "a useful learning quest\n")
    expect(first.reload.moderation_status).to eq("pending")
    expect(second.reload.moderation_status).to eq("pending")
    execute_script("document.activeElement.blur()") # Leave the reason field so shortcuts resume.
    send_keys("a")
    expect(page).to have_content("Decision recorded.")
    expect(first.reload).to be_approved
    expect(page).to have_button("Hide")
    click_link "Next (J)"
    expect(page).to have_css("h1", text: /Second queue quest/i)
    fill_in "Reason or note", with: "Needs a clearer learning goal."
    click_button "Reject"
    expect(page).to have_content("Decision recorded.")
    expect(second.reload.moderation_status).to eq("rejected")
    click_link "Back to queue"
    expect(page).to have_content("Nothing waiting here.")
    expect(page).to have_link("Spectrums 1")
  end
end
