require "rails_helper"

RSpec.describe "Group progress and remaining practice" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team) }
  let(:jalen) { create(:player, first_name: "Jalen", last_name: "Brunson", team: team, photo_urls: [ "/icon.png" ]) }
  let(:josh) { create(:player, first_name: "Josh", last_name: "Hart", team: create(:team, league: team.league), active: false, photo_urls: [ "/icon.png" ]) }
  let(:group) { PlayerGroup.create!(name: "Knicks names", players: [ jalen, josh ]) }

  before do
    create(:game_attempt, ace: ace, subject_entity: jalen, is_correct: true)
    sign_in ace
  end

  it "shows coverage and starts practice on the names not yet answered correctly" do
    visit player_group_path(group)
    expect(page).to have_content("1 of 2")
    expect(page).to have_content("Not practiced")
    click_link "Practice remaining 1"
    expect(page).to have_select("Members to practice", selected: "Not yet answered correctly")
    expect(page).to have_content("1 player available")
  end

  it "keeps the remaining-members filter when switching game modes" do
    visit player_group_path(group)
    click_link "Practice remaining 1"
    choose "Image Recognition"
    expect(page).to have_css(".round-start-dock", text: "Image Recognition")
    expect(page).to have_select("Members to practice", selected: "Not yet answered correctly")
    click_button "Start round"
    expect(ace.game_rounds.last).to have_attributes(game_type: "image_recognition")
    expect(ace.game_rounds.last.question.fetch("subject_id")).to eq(josh.id)
    expect(page).to have_css(".round-choice", count: 2)
  end

  it "marks the group complete once the last name is answered correctly" do
    visit player_group_path(group)
    click_link "Practice remaining 1"
    click_button "Start round"
    find(".round-choice[value='#{josh.id}']").click
    click_button "Round summary"
    click_link "Play again"
    expect(page).to have_button("Start round", disabled: true)
    expect(page).to have_content("Choose All members")
    visit player_group_path(group)
    expect(page).to have_content("Every current member has been answered correctly")
    expect(page).to have_no_link("Practice remaining")
  end

  it "offers practice on later misses" do
    create(:game_attempt, ace: ace, subject_entity: josh, is_correct: true)
    create(:game_attempt, ace: ace, subject_entity: josh, is_correct: false)
    visit player_group_path(group)
    expect(page).to have_content("2 of 2")
    click_link "Practice misses"
    expect(page).to have_select("Members to practice", selected: "Needs practice")
    expect(page).to have_content("1 player available")
  end

  it "drops the members filter when the round leaves the group" do
    visit player_group_path(group)
    click_link "Practice remaining 1"
    select "Any players", from: "Player group"
    expect(page).to have_no_field("Members to practice")
    expect(page).to have_no_content("requires a player group")
  end
end
