require "rails_helper"

RSpec.describe "Play layout", type: :system do
  let(:fan) { create(:ace, username: "bleacher_creature", display_name: "Rosa Diaz") }
  let(:league) { create(:league, name: "National Basketball Association", abbreviation: "NBA", sport: create(:sport, name: "Basketball")) }
  let(:team) { create(:team, league: league, territory: "New York", mascot: "Knicks", abbreviation: "NYK", primary_color: "#006BB6", secondary_color: "#F58426") }
  let(:rival) { create(:team, league: league, territory: "Golden State", mascot: "Warriors", abbreviation: "GSW") }
  let(:player) { create(:player, team: team, first_name: "Jalen", last_name: "Brunson", current_position: "PG") }
  let(:group) { PlayerGroup.create!(name: "Knicks backcourt", description: "Guards to learn this week.", players: [ player, create(:player, team: rival, first_name: "Stephen", last_name: "Curry") ]) }
  let(:quest) { create(:quest, name: "Know the Knicks starting five", description: "Name every starter by sight.") }

  before do
    create(:familiarity)
    create(:game_attempt, ace: fan, subject_entity: player, chosen_entity: rival, is_correct: false)
    phone_viewport
  end

  it "fits Play pages on a phone" do
    sign_in fan
    expect_pages_to_fit strength_path, player_path(player), team_path(team), players_path, teams_path, quests_path, quest_path(quest),
      player_groups_path, player_group_path(group), strength_team_match_path(league_id: league.id), new_division_game_path,
      new_player_rating_path(player, spectrum_id: Spectrum.first.id), profile_path
  end

  it "fits a visitor's preview and sign-up on a phone" do
    expect_pages_to_fit strength_path, player_path(player), new_ace_registration_path
  end

  it "fits the admin's group editor on a phone" do
    sign_in create(:ace, :admin)
    expect_pages_to_fit edit_player_group_path(group)
  end

  it "gives each mobile Play tab a 44 pixel touch target" do
    sign_in fan
    visit strength_path
    heights = page.evaluate_script("Array.from(document.querySelectorAll('[aria-label=\"Play navigation mobile\"] a')).map(link => link.getBoundingClientRect().height)")
    expect(heights.size).to eq(5)
    expect(heights).to all(be >= 44)
  end

  it "scrolls a visitor's sign-in message into view after a tap at the bottom of the screen" do
    create(:rating, rated: player, spectrum: Spectrum.first, value: 80)
    visit player_path(player)
    row = "#rating_spectrum_#{Spectrum.first.id}_player_#{player.id}"
    page.execute_script("const track = document.querySelector('#{row} .slider-track'); window.scrollTo(0, track.getBoundingClientRect().bottom + window.scrollY - window.innerHeight)")
    find("#{row} button[aria-label^='Sign in to rate']").click
    expect(page).to have_css("#{row} .status-indicator", text: "You need to sign in to rate.")
    expect(rect("#{row} .slider-status")["bottom"]).to be <= page.evaluate_script("window.innerHeight")
  end

  it "shows the skip link on screen when it takes focus on every side" do
    sign_in create(:ace, :admin)
    [ strength_path, feed_path, moderation_path, admin_path ].each do |path|
      visit path
      find("body").send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.textContent")).to eq("Skip to content")
      expect(rect(".shell-skip-link")["y"]).to be >= 0
    end
  end
end
