require "rails_helper"

RSpec.describe "Flash cards" do
  let(:team) { create(:team, territory: "Cincinnati", mascot: "Reds") }
  let!(:players) { create_list(:player, 2, team: team, current_position: "SP") }

  before { create(:team, league: team.league) }

  it "bulges the given name, then the family name, then shows the team and position" do
    visit flash_cards_path(team_ids: [ team.id ], delay: 5)
    expect(page).to have_css(".flash-card[data-step='1']:not([hidden]) .flash-card-given")
    expect(page).to have_css(".round-game-progress strong", text: "1 / 2")
    travel 1.5.seconds
    expect(page).to have_css(".flash-card[data-step='2']:not([hidden]) .flash-card-family")
    travel 1.5.seconds
    expect(page).to have_css(".flash-card[data-step='3']:not([hidden]) .flash-card-team-phrase", text: team.name)
    travel 1.5.seconds
    expect(page).to have_css(".flash-card[data-step='4']:not([hidden]) .flash-card-position", text: "(SP)")
    travel 1.seconds
    expect(page).to have_css(".round-game-progress strong", text: "2 / 2")
    expect(page).to have_css(".flash-card[data-step='1']:not([hidden])")
  end

  it "pauses the deck" do
    visit flash_cards_path(team_ids: [ team.id ], delay: 5)
    click_button "Pause"
    expect(page).to have_button("Play")
    travel 6.seconds
    expect(page).to have_css(".round-game-progress strong", text: "1 / 2")
  end

  it "flips through at your own pace, switches pace mid-deck, and offers a quiz on the deck" do
    visit new_game_round_path(team_ids: [ team.id ])
    choose "Flash Cards"
    expect(page).to have_css(".round-start-dock", text: "Flash Cards · 2 cards")
    click_button "Start flash cards"
    expect(page).to have_css(".flash-card[data-step='4']", text: "(SP)")
    expect(page).to have_button("Previous", disabled: true)
    expect(page).to have_no_button("Pause")
    click_button "Next"
    find("body").send_keys :arrow_left
    expect(page).to have_css(".round-game-progress strong", text: "1 / 2")

    click_button "2s"
    expect(page).to have_button("Pause")
    expect(page).to have_current_path(/delay=2/)
    travel 3.seconds
    expect(page).to have_css(".round-game-progress strong", text: "2 / 2")
    click_button "Tap"
    expect(page).to have_no_button("Pause")
    expect(page).to have_link("Shuffle again", href: /delay=0/, visible: :all)

    click_button "Next"
    expect(page).to have_content(/That’s the deck\./i)
    click_link "Quiz me on these"
    expect(page).to have_checked_field("Team Match")
    expect(page).to have_content("Focused players")
  end
end
