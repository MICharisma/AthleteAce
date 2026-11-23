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

  context "with two quests filtered from the queue" do
    let(:reviewer) { create(:ace, moderator: true) }
    let(:author) { create(:ace) }
    let!(:first) { create(:quest, created_by: author, name: "First queue quest") }
    let!(:second) { create(:quest, created_by: author, name: "Second queue quest") }

    before do
      create(:spectrum, created_by: author, name: "Other content")
      sign_in reviewer
      visit moderation_path
      click_link "Quests 2"
    end

    def focused(attribute) = evaluate_script("document.activeElement.getAttribute('#{attribute}')")

    it "lists only that type" do
      expect(page).to have_content("First queue quest")
      expect(page).to have_no_content("Other content")
    end

    it "moves through the list with J and K and opens an item with Enter" do
      send_keys("j")
      expect(focused("aria-label")).to eq("Review First queue quest")
      send_keys("j")
      expect(focused("aria-label")).to eq("Review Second queue quest")
      send_keys("k", :enter)
      expect(page).to have_css("h1", text: /First queue quest/i)
    end

    it "steps between queued items with J and K on an item page" do
      click_link "First queue quest"
      send_keys("j")
      expect(page).to have_css("h1", text: /Second queue quest/i)
      expect(page).to have_content("2 of 2 · Quests · pending")
      send_keys("k")
      expect(page).to have_css("h1", text: /First queue quest/i)
    end

    it "pauses shortcuts while typing a reason" do
      click_link "First queue quest"
      send_keys("?")
      expect(page).to have_content("Shortcuts pause while you type in a field.")
      send_keys("r")
      expect(focused("id")).to eq("reason")
      send_keys("a useful learning quest", :enter)
      expect(page).to have_field("Reason or note", with: "a useful learning quest\n")
      expect([ first.reload, second.reload ].map(&:moderation_status)).to eq(%w[pending pending])
    end

    it "approves with A once focus leaves the reason field" do
      click_link "First queue quest"
      fill_in "Reason or note", with: "A useful learning quest."
      execute_script("document.activeElement.blur()") # Leave the reason field so shortcuts resume.
      send_keys("a")
      expect(page).to have_content("Decision recorded.")
      expect(page).to have_button("Hide")
      expect(first.reload).to be_approved
    end

    it "points to other waiting types once the filtered queue is empty" do
      review_post(first, action: "approve", reviewer: reviewer)
      click_link "Second queue quest"
      fill_in "Reason or note", with: "Needs a clearer learning goal."
      click_button "Reject"
      expect(page).to have_content("Decision recorded.")
      expect(second.reload.moderation_status).to eq("rejected")
      click_link "Back to queue"
      expect(page).to have_content("Nothing waiting here.")
      expect(page).to have_link("Spectrums 1")
    end
  end
end
