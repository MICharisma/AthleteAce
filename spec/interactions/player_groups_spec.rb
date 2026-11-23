require "rails_helper"

RSpec.describe "Curated group play" do
  let(:ace) { create(:ace, :admin) }
  let!(:team) { create(:team) }
  let!(:rival) { create(:team, league: team.league) }
  let!(:jalen) { create(:player, first_name: "Jalen", last_name: "Brunson", team: team, photo_urls: [ "/icon.png" ]) }
  let!(:josh) { create(:player, first_name: "Josh", last_name: "Hart", team: rival, active: false, photo_urls: [ "/icon.png" ]) }
  let!(:group) { PlayerGroup.create!(name: "Knicks names", description: "Two names to learn.", players: [ jalen, josh ]) }

  it "browses and plays a group in the saved player modes" do
    sign_in ace
    visit player_groups_path
    click_link group.name
    expect(page).to have_content("Two names to learn.")
    click_link "Practice group"
    expect(page).to have_select("Player group", selected: group.name)
    click_button "Start round"
    expect(page).to have_css(".round-game-progress", text: "1 / 2")
    round = ace.game_rounds.last
    find(".round-choice[value='#{round.question.fetch('target_id')}']").click
    expect(page).to have_css(".round-feedback", text: /Correct/i)

    %w[multiple_choice image_recognition].each do |mode|
      visit new_game_round_path(player_group_id: group.id, game_type: mode)
      expect(page).to have_select("Player group", selected: group.name)
      click_button "Start round"
      expect(page).to have_css(".round-game-progress", text: "1 / 2")
      round = ace.game_rounds.last
      if mode == "image_recognition"
        expect(page).to have_css(".round-recognition-photo") { |image| image.evaluate_script("this.complete && this.naturalWidth > 0") }
      end
      find(".round-choice[value='#{round.question.fetch('target_id')}']").click
      expect(page).to have_css(".round-feedback", text: /Correct/i)
    end
    expect(ace.game_attempts.count).to eq(3)
  end

  it "lets an admin rename a group" do
    sign_in ace
    visit edit_player_group_path(group)
    fill_in "Name", with: "Names for the weekend"
    click_button "Update Player group"
    expect(page).to have_content("Player group updated.")
    expect(page).to have_content(/Names for the weekend/i)
    expect(group.reload.players.count).to eq(2)
  end
end
