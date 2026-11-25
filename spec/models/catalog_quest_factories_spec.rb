require "rails_helper"

RSpec.describe "Catalog quest factories" do
  it "includes listed starters and players observed opening a game as pitcher" do
    league = create(:mlb)
    team = create(:team, league: league)
    listed = create(:player, team: team, first_name: "Avery", last_name: "Morgan", current_position: "SP")
    opened = create(:player, team: team, first_name: "Nico", last_name: "Reyes")
    relief = create(:player, team: team, first_name: "Theo", last_name: "Brooks", current_position: "P")
    changed_position = create(:player, team: team, first_name: "Jesse", last_name: "Park")
    season = create(:season, league: league)
    campaign = Campaign.create!(team: team, season: season)
    game = Contest.create!(name: "Opening day", kind: "game", context: league, season: season)
    contestant = Contestant.create!(contest: game, campaign: campaign)
    pitcher = create(:position, sport: league.sport, name: "Pitcher", abbreviation: "P")
    first_base = create(:position, sport: league.sport, name: "First Base", abbreviation: "1B")

    Appearance.create!(contestant: contestant, player: opened, starter: true)
      .position_assignments.create!(position: pitcher, sequence: 1)
    Appearance.create!(contestant: contestant, player: relief, starter: false)
      .position_assignments.create!(position: pitcher, sequence: 1)
    switched = Appearance.create!(contestant: contestant, player: changed_position, starter: true)
    switched.position_assignments.create!(position: first_base, sequence: 1)
    switched.position_assignments.create!(position: pitcher, sequence: 2)

    quest = create(:starting_pitchers_quest)

    expect(quest.required_achievements.sole.target.players).to contain_exactly(listed, opened)
  end

  it "snapshots the players who are exactly 21 and on NFL teams on the selected date" do
    as_of = Date.new(2026, 11, 25)
    team = create(:team, league: create(:nfl))
    birthday = create(:player, team: team, birthdate: as_of.years_ago(21))
    last_day = create(:player, team: team, birthdate: as_of.years_ago(22).next_day)
    create(:player, team: team, birthdate: as_of.years_ago(21).next_day)
    create(:player, team: team, birthdate: as_of.years_ago(22))
    create(:player, team: team, birthdate: nil)
    create(:player, birthdate: birthday.birthdate)

    goal = create(:nfl_twenty_one_goal, as_of: as_of)
    entry = goal.goal_achievements.sole

    expect(entry.required_player_ids).to contain_exactly(birthday.id, last_day.id)
    expect(entry.practice_scope).to include("player_group_id" => entry.achievement.target_id)
    entry.achievement.target.update!(players: [])
    expect(entry.reload.required_player_ids).to contain_exactly(birthday.id, last_day.id)
  end

  it "uses the player's birthplace for Florida-born rather than the team's home stadium" do
    country = create(:country, name: "United States", abbreviation: "US")
    florida = create(:state, name: "Florida", abbreviation: "FL", country: country)
    tampa = create(:city, name: "Tampa", state: florida)
    born_there = create(:player, first_name: "Jordan", last_name: "Rivera", birth_city: tampa)
    home_team = create(:team, stadium: create(:stadium, city: tampa))
    create(:player, team: home_team, birth_city: nil)
    foreign_florida = create(:city, state: create(:state, name: "Florida", country: create(:country, abbreviation: "UY")))
    create(:player, birth_city: foreign_florida)

    quest = create(:florida_born_quest)

    expect(quest.required_achievements.sole.target.players).to contain_exactly(born_there)
  end

  it "uses one required team achievement and roster snapshot per Florida home team" do
    country = create(:country, name: "United States", abbreviation: "US")
    florida = create(:state, name: "Florida", country: country)
    tampa = create(:city, name: "Tampa", state: florida)
    tampa_bay = create(:team, territory: "Tampa Bay", mascot: "Rays", stadium: create(:stadium, city: tampa))
    miami = create(:team, territory: "Miami", mascot: "Marlins",
      stadium: create(:stadium, city: create(:city, name: "Miami", state: florida)))
    outside_team = create(:team, stadium: create(:stadium))
    tampa_player = create(:player, team: tampa_bay)
    miami_player = create(:player, team: miami)
    create(:player, team: outside_team, birth_city: tampa)

    goal = create(:florida_home_teams_goal)
    highlights = goal.quest.highlights.ordered.includes(:achievement)
    entries = goal.goal_achievements.includes(:achievement).index_by { |entry| entry.achievement.target_id }

    expect(highlights.map(&:required?)).to eq([true, true])
    expect(highlights.map { |highlight| highlight.achievement.target }).to eq([miami, tampa_bay])
    expect(entries.fetch(miami.id).required_player_ids).to eq([miami_player.id])
    expect(entries.fetch(tampa_bay.id).required_player_ids).to eq([tampa_player.id])
    expect(entries.fetch(tampa_bay.id).practice_scope).to include("team_id" => tampa_bay.id)
  end

  it "reports an empty cohort without creating an empty quest" do
    expect { create(:florida_born_quest, player_scope: Player.none) }
      .to raise_error(ArgumentError, /No catalog players match Sunshine State Birthdays/)
    expect(Quest.where(name: "Sunshine State Birthdays")).to be_empty
  end
end
