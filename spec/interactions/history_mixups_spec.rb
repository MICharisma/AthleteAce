require "rails_helper"

RSpec.describe "Practice player mix-ups" do
  let(:ace) { create(:ace) }
  let(:jalen) { create(:player, first_name: "Jalen", last_name: "Brunson", team: nil, active: false, photo_urls: [ "/icon.png" ]) }
  let(:josh) { create(:player, first_name: "Josh", last_name: "Hart", team: nil, photo_urls: [ "/icon.png" ]) }
  let(:pair) { [ jalen.id, josh.id ] }
  let(:saved) { ace.game_rounds.last }

  before do
    create(:player, first_name: "Mikal", last_name: "Bridges")
    round = GameRoundSetup.new(game_type: "name_ciphers", player_ids: pair, include_inactive: true).start!(ace)
    round.answer!(at: 0, choice_id: (pair - [ round.question.fetch("target_id") ]).sole)
    sign_in ace
    visit strength_game_attempts_path
  end

  def drill_with_images
    click_link "Drill names"
    choose "Image Recognition"
    click_button "Start round"
  end

  it "lists a player mix-up and drills that pair" do
    expect(page).to have_content(/Players you mix up/i)
    expect(page).to have_content("1 mix-up")
    click_link "Drill names"
    expect(page).to have_content("Focused players · Jalen Brunson · Josh Hart")
  end

  it "keeps the pair when switching game modes" do
    click_link "Drill names"
    choose "Image Recognition"
    expect(page).to have_css(".round-start-dock", text: "Image Recognition")
    expect(page).to have_content("2 players available")
    click_button "Start round"
    expect(saved.game_type).to eq("image_recognition")
    expect(saved.questions.map { |question| question.fetch("subject_id") }).to match_array(pair)
    expect(all(".round-choice").map(&:text).join).not_to include("Mikal")
  end

  it "keeps the pair when playing the drill again" do
    drill_with_images
    2.times do |position|
      find(".round-choice[value='#{saved.reload.question.fetch('target_id')}']").click
      click_button(position.zero? ? "Next" : "Round summary")
    end
    expect(page).to have_content("2 / 2")
    click_link "Play again"
    expect(page).to have_content("Focused players · Jalen Brunson · Josh Hart")
  end
end
