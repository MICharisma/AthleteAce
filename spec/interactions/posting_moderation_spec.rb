require "rails_helper"

RSpec.describe "Posting moderation workflow" do
  let(:ace) { create(:ace, username: "wrigley_wes", display_name: "Wes Miller") }
  let(:reviewer) { create(:ace, moderator: true, username: "roster_rae", display_name: "Rae Carter") }
  let(:player) { create(:player, first_name: "Nico", last_name: "Hoerner") }

  def act(kind, **attributes)
    Moderation::PostingAction.call(ace: ace, actor: reviewer, kind: kind, attributes: { request_key: SecureRandom.uuid, **attributes })
  end

  def mute
    act "mute", reason: "Please keep new posts about the players.", duration_hours: "24", note: "Private mute context."
  end

  context "as a reviewer on the ace's profile" do
    before do
      sign_in reviewer
      create(:quest, created_by: ace, name: "Know every Cubs starter")
      visit ace_profile_path(ace)
    end

    it "records a warning tied to one of the ace's submissions" do
      find("summary", text: /\AWarn\z/i).click
      fill_in "Warning reason", with: "Keep proposals specific to the roster."
      select "Know every Cubs starter", from: "Related submission"
      click_button "Record warning"
      expect(page).to have_content("Posting moderation action recorded.")
      expect(page).to have_content("Keep proposals specific to the roster.")
      expect(ace.warnings.sole.subject_name).to eq("Know every Cubs starter")
    end

    it "saves a private moderator note" do
      find("summary", text: /Add moderator note/i).click
      fill_in "Internal note", with: "Private review context for the team."
      click_button "Save moderator note"
      expect(page).to have_content("Private review context for the team.")
    end

    it "mutes posting with a public reason and a private note" do
      find("summary", text: /\AMute from posting\z/i).click
      select "24 hours", from: "Duration"
      fill_in "Mute reason", with: "Please keep new posts about the players."
      fill_in "Private note for moderators", with: "Private mute context."
      click_button "Mute from posting"
      expect(page).to have_content("Please keep new posts about the players.")
      expect(page).to have_content("Private mute context.")
      expect(ace.active_posting_mute).to be_present
    end

    it "ends a mute early with a reason" do
      mute
      visit ace_profile_path(ace)
      find("summary", text: /End mute early/i).click
      fill_in "Reason for ending mute", with: "Ready to contribute again."
      click_button "End mute"
      expect(page).to have_content(/Ended early/i)
      expect(page).to have_content("Ready to contribute again.")
      expect(ace.active_posting_mute).to be_nil
    end
  end

  context "as the moderated ace" do
    before { sign_in ace }

    it "shows the public reasons but never the private notes" do
      act "warn", reason: "Keep proposals specific to the roster."
      act "note", body: "Private review context for the team."
      mute
      visit posting_status_path
      expect(page).to have_content("Keep proposals specific to the roster.")
      expect(page).to have_content("Please keep new posts about the players.")
      expect(page).to have_no_content("Private mute context.")
      expect(page).to have_no_content("Private review context for the team.")
    end

    it "pauses posting during a mute but keeps Play open" do
      mute
      visit new_shout_out_draft_path
      expect(page).to have_css("h1", text: /Posting paused/i)
      click_link "Continue playing"
      expect(page).to have_current_path(strength_path)
      expect(page).to have_content("You can still play and read.")
    end

    it "posts again once a mute has ended" do
      mute
      act "end_mute", reason: "Ready to contribute again.", mute_id: ace.active_posting_mute.id
      visit new_shout_out_draft_path(target_type: "Player", target_id: player.id)
      expect(page).to have_no_css("h1", text: /Posting paused/i)
      fill_in "Your message", with: "A remarkable effort in every inning."
      click_button "Save draft"
      expect(page).to have_content("Draft saved. Only you can see it.")
    end
  end
end
