require "rails_helper"

RSpec.describe "Writing private shout-out drafts" do
  context "for a signed-in fan" do
    let(:ace) { create(:ace) }
    let!(:player) { create(:player, first_name: "Jalen", last_name: "Brunson") }
    let(:count) { '[data-draft-composer-target="count"]' }

    before { sign_in ace }

    def edit_draft
      draft = ace.shout_out_drafts.create!(target: player, message: "What a finish!")
      visit edit_shout_out_draft_path(draft)
      draft
    end

    it "searches for a target and saves a draft with an emoji" do
      visit feed_path
      click_link "Write a draft"
      expect(page).to have_button("Save draft", disabled: true)
      fill_in "Search players and teams", with: "Brunson"
      find('button[aria-label="Choose Jalen Brunson"]').click
      expect(page).to have_css(".draft-selected", text: player.name)
      fill_in "Your message", with: "What a finish! "
      find('button[aria-label="Add applause emoji"]').click
      expect(page).to have_css('[data-draft-composer-target="preview"]', text: "What a finish! 👏")
      expect(page).to have_css(count, text: "16 / 200 characters")
      click_button "Save draft"
      expect(page).to have_content("Draft saved. Only you can see it.")
      expect(page).to have_field("Your message", with: "What a finish! 👏")
      expect(ace.shout_out_drafts.sole.target).to eq(player)
    end

    it "counts emoji as single characters, ignores surrounding spaces and blocks more than 200" do
      edit_draft
      fill_in "Your message", with: "\u00A0#{'👏' * 200}\u00A0"
      expect(page).to have_css(count, text: "200 / 200 characters")
      expect(page).to have_button("Save draft", disabled: false)
      fill_in "Your message", with: "👏" * 201
      expect(page).to have_button("Save draft", disabled: true)
    end

    it "saves an edit with the next lock version" do
      draft = edit_draft
      fill_in "Your message", with: "Huge fourth quarter!"
      click_button "Save draft"
      expect(page).to have_content("Draft saved. Only you can see it.")
      expect(page).to have_css('input[name="shout_out_draft[lock_version]"][value="1"]', visible: false)
      expect(draft.reload.message).to eq("Huge fourth quarter!")
    end

    it "lists and deletes drafts" do
      edit_draft
      click_link "My drafts"
      expect(page).to have_css(".draft-card", text: "What a finish!")
      click_button "Delete draft"
      expect(page).to have_content("No drafts yet.")
      expect(ace.shout_out_drafts.reload).to be_empty
    end
  end

  it "prefills an entity from its page and shows server validation errors without losing text" do
    sign_in create(:ace)
    team = create(:team, territory: "New York", mascot: "Knicks")
    visit team_path(team)
    click_link "Write a shout-out draft"
    expect(page).to have_css(".draft-selected", text: team.name)
    fill_in "Your message", with: "See example.com for highlights"
    click_button "Save draft"
    expect(page).to have_css('[role="alert"]', text: "cannot include links or web addresses")
    expect(page).to have_field("Your message", with: "See example.com for highlights")
    expect(page).to have_css(".draft-selected", text: team.name)
    expect(ShoutOutDraft.count).to eq(0)
  end
end
