require "rails_helper"

RSpec.describe "Following from entity pages" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team, territory: "New York", mascot: "Knicks", abbreviation: "NYK") }
  let!(:player) { create(:player, team: team, first_name: "Jalen", last_name: "Brunson") }

  before do
    create(:player, team: create(:team, league: team.league))
    sign_in ace
  end

  it "follows a team without leaving its page" do
    path = team_path(team)
    visit path
    find("#action_bar_team_#{team.id} summary").click
    within("#action_bar_team_#{team.id}") do
      click_button "Follow"
      expect(page).to have_button("Following")
    end
    expect(page).to have_current_path(path)
    expect(ace.follows.where(followable: team)).to exist
  end

  it "toggles following a player in place" do
    visit player_path(player)
    find("#action_bar_player_#{player.id} summary").click
    within("#action_bar_player_#{player.id}") do
      click_button "Follow"
      expect(page).to have_button("Following")
      click_button "Following"
      expect(page).to have_button("Follow")
    end
    expect(ace.follows.where(followable: player)).to be_empty
  end

  it "lists follows on the profile and unfollows from there" do
    ace.follows.create!(followable: team)
    follow = ace.follows.create!(followable: player)
    visit profile_path
    expect(page).to have_css("#profile-following-title", text: /Following/i)
    expect(page).to have_content(team.name)
    within("#follow_#{follow.id}") { click_button "Following" }
    expect(page).to have_no_link(player.name)
    expect(ace.follows.where(followable: player)).to be_empty
  end

  it "builds a Quick round from a followed team" do
    ace.follows.create!(followable: team)
    visit strength_path
    within("main") { click_button "Quick round" }
    expect(page).to have_css(".round-game-progress", text: "1 / 1")
    expect(ace.game_rounds.last.question.fetch("subject_id")).to eq(player.id)
  end
end
