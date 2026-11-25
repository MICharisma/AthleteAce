module QuestFactoryCohorts
  module_function

  def in_league(players, abbreviation)
    players.joins(team: :league).where(leagues: { abbreviation: abbreviation })
  end

  def in_sport(players, name)
    sports = Sport.where(name: name)
    teams = Team.where(league: League.where(sport: sports))
    players.where(sport: sports).or(players.where(sport_id: nil, team: teams))
  end

  def recorded_at_position(players, *labels)
    labels = labels.map(&:downcase)
    assignments = PositionAssignment.where(position: positions_named(labels))
    roster_entries = RosterEntry.where(id: assignments.where(subject_type: "RosterEntry").select(:subject_id))
    appearances = Appearance.where(id: assignments.where(subject_type: "Appearance").select(:subject_id))

    players.where("LOWER(players.current_position) IN (?)", labels)
      .or(players.where(id: assignments.where(subject_type: "Player").select(:subject_id)))
      .or(players.where(id: roster_entries.select(:player_id)))
      .or(players.where(id: appearances.select(:player_id)))
  end

  def positions_named(labels)
    Position.where("LOWER(name) IN (:labels) OR LOWER(abbreviation) IN (:labels)", labels: labels)
  end

  def starting_pitchers(players)
    baseball_players = in_sport(players, "Baseball")
    opening_pitchers = PositionAssignment.where(subject_type: "Appearance", sequence: 1, position: positions_named(%w[p pitcher]))
    starts = Appearance.where(starter: true, id: opening_pitchers.select(:subject_id))

    recorded_at_position(baseball_players, "SP", "Starting Pitcher").or(baseball_players.where(id: starts.select(:player_id)))
  end

  def ages(players, as_of, minimum:, maximum: nil)
    oldest_birthdate = as_of.years_ago(maximum + 1).next_day if maximum
    players.where(birthdate: oldest_birthdate..as_of.years_ago(minimum))
  end

  def home_state(players, *names)
    players.joins(team: { stadium: { city: :state } }).where(states: { name: names })
  end

  def roster_entries(league)
    RosterEntry.joins(roster: { campaign: { season: :league } }).where(leagues: { abbreviation: league })
  end

  def f1_results
    Appearance.joins(campaign: { season: :league }).where(leagues: { abbreviation: "F1" })
  end
end

FactoryBot.define do
  cohorts = QuestFactoryCohorts
  variants = {
    starting_pitchers: ["Rotation Roll Call", "Learn every baseball player recorded as a starting pitcher.",
      ->(players, _) { cohorts.starting_pitchers(players) }],
    nfl_twenty_one: ["Twenty-One in the NFL", "Learn every player who is 21 and currently assigned to an NFL team.",
      ->(players, as_of) { cohorts.ages(cohorts.in_league(players, "NFL"), as_of, minimum: 21, maximum: 21) }],
    florida_born: ["Sunshine State Birthdays", "Learn every player with a recorded birthplace in Florida.",
      ->(players, _) { players.joins(birth_city: :state).where(states: { name: "Florida", country: Country.where(abbreviation: "US") }) }],
    mlb_catchers: ["Behind the Plate", "Learn the players on MLB teams with a recorded catcher position.",
      ->(players, _) { cohorts.recorded_at_position(cohorts.in_league(players, "MLB"), "C", "Catcher") }],
    mlb_middle_infielders: ["Turn Two", "Learn the players on MLB teams recorded at second base or shortstop.",
      ->(players, _) { cohorts.recorded_at_position(cohorts.in_league(players, "MLB"), "2B", "Second Base", "SS", "Shortstop") }],
    nfl_quarterbacks: ["Under Center", "Learn the players on NFL teams with a recorded quarterback position.",
      ->(players, _) { cohorts.recorded_at_position(cohorts.in_league(players, "NFL"), "QB", "Quarterback") }],
    nfl_receivers_and_tight_ends: ["Passing Targets", "Learn the players on NFL teams recorded as wide receivers or tight ends.",
      ->(players, _) { cohorts.recorded_at_position(cohorts.in_league(players, "NFL"), "WR", "Wide Receiver", "TE", "Tight End") }],
    nfl_defensive_backs: ["No-Fly Zone", "Learn the players on NFL teams recorded as cornerbacks, safeties, or defensive backs.",
      ->(players, _) { cohorts.recorded_at_position(cohorts.in_league(players, "NFL"), "CB", "Cornerback", "S", "Safety", "FS", "Free Safety", "SS", "Strong Safety", "DB", "Defensive Back") }],
    nfl_specialists: ["Fourth Down Crew", "Learn the players on NFL teams recorded as kickers, punters, or long snappers.",
      ->(players, _) { cohorts.recorded_at_position(cohorts.in_league(players, "NFL"), "K", "PK", "Kicker", "Place Kicker", "P", "Punter", "LS", "Long Snapper") }],
    premier_league_teenagers: ["Teenagers in the Premier League", "Learn the players aged 13 through 19 on Premier League teams.",
      ->(players, as_of) { cohorts.ages(cohorts.in_league(players, "EPL"), as_of, minimum: 13, maximum: 19) }],
    mls_under_twenty_three: ["MLS Under 23", "Learn the players younger than 23 on MLS teams.",
      ->(players, as_of) { cohorts.ages(cohorts.in_league(players, "MLS"), as_of, minimum: 0, maximum: 22) }],
    mlb_thirty_five_and_up: ["Still in the Lineup", "Learn the players aged 35 or older on MLB teams.",
      ->(players, as_of) { cohorts.ages(cohorts.in_league(players, "MLB"), as_of, minimum: 35) }],
    nfl_thirty_and_up: ["Thirty and Counting", "Learn the players aged 30 or older on NFL teams.",
      ->(players, as_of) { cohorts.ages(cohorts.in_league(players, "NFL"), as_of, minimum: 30) }],
    nba_thirty_and_up: ["The NBA's Thirty Club", "Learn the players aged 30 or older on NBA teams.",
      ->(players, as_of) { cohorts.ages(cohorts.in_league(players, "NBA"), as_of, minimum: 30) }],
    new_years_day_birthdays: ["New Year's Starting Line", "Learn the players born on January 1.",
      ->(players, _) { players.where("EXTRACT(MONTH FROM players.birthdate) = 1 AND EXTRACT(DAY FROM players.birthdate) = 1") }],
    midyear_birthdays: ["June, July, and August", "Learn the players born in June, July, or August.",
      ->(players, _) { players.where("EXTRACT(MONTH FROM players.birthdate) BETWEEN 6 AND 8") }],
    florida_home_teams: ["Florida Home Fields", "Learn the players on teams whose recorded home venue is in Florida.",
      ->(players, _) { cohorts.home_state(players, "Florida") }],
    texas_nfl_teams: ["Texas Sundays", "Learn the players on NFL teams with a home venue in Texas.",
      ->(players, _) { cohorts.home_state(cohorts.in_league(players, "NFL"), "Texas") }],
    california_mlb_teams: ["California Diamonds", "Learn the players on MLB teams with a home venue in California.",
      ->(players, _) { cohorts.home_state(cohorts.in_league(players, "MLB"), "California") }],
    canadian_nhl_teams: ["Hockey North of the Border", "Learn the players on NHL teams with a home venue in Canada.",
      ->(players, _) { cohorts.in_league(players, "NHL").joins(team: { stadium: { city: { state: :country } } }).where(countries: { name: "Canada" }) }],
    london_premier_league_teams: ["Saturday in London", "Learn the players on Premier League teams with a home venue recorded in London.",
      ->(players, _) { cohorts.in_league(players, "EPL").joins(team: { stadium: :city }).where(cities: { name: "London" }) }],
    subway_series_teams: ["Subway Series Roll Call", "Learn the players on the Yankees and Mets.",
      ->(players, _) { cohorts.in_league(players, "MLB").where(teams: { abbreviation: %w[NYY NYM] }) }],
    original_six_teams: ["Original Six Sweaters", "Learn the players on the Bruins, Blackhawks, Red Wings, Canadiens, Rangers, and Maple Leafs.",
      ->(players, _) { cohorts.in_league(players, "NHL").where(teams: { abbreviation: %w[BOS CHI DET MTL NYR TOR] }) }],
    f1_front_of_grid: ["Front of the Grid", "Learn the Formula One drivers who started first in a recorded race.",
      ->(players, _) { players.where(id: cohorts.f1_results.where("appearances.statistics @> ?", { grid: 1 }.to_json).select(:player_id)) }],
    f1_podium_finishers: ["Podium Club", "Learn the Formula One drivers with a recorded first-, second-, or third-place finish.",
      ->(players, _) { players.where(id: cohorts.f1_results.where("appearances.statistics ->> 'finish_position' IN (?)", %w[1 2 3]).select(:player_id)) }],
    nba_multiple_roster_seasons: ["Back for Another Season", "Learn NBA players listed on rosters in at least two recorded seasons.",
      ->(players, _) { players.where(id: cohorts.roster_entries("NBA").group(:player_id).having("COUNT(DISTINCT campaigns.season_id) >= 2").select(:player_id)) }],
    mlb_multiple_clubs: ["New Locker, Same League", "Learn players listed on rosters for at least two different MLB teams.",
      ->(players, _) { players.where(id: cohorts.roster_entries("MLB").group(:player_id).having("COUNT(DISTINCT campaigns.team_id) >= 2").select(:player_id)) }],
    england_and_europe_rosters: ["League and European Nights", "Learn players listed on both a Premier League roster and a Champions League roster.",
      ->(players, _) { players.where(id: cohorts.roster_entries("EPL").select(:player_id)).where(id: cohorts.roster_entries("UCL").select(:player_id)) }],
    nba_championship_rosters: ["Championship Roster Recall", "Learn players listed on an NBA championship team's roster in its title season.",
      ->(players, _) {
        winners = TitleAward.team_titles.where(key: "nba_championship").joins(:winner).select("contestants.campaign_id")
        players.where(id: cohorts.roster_entries("NBA").where(campaigns: { id: winners }).select(:player_id))
      }],
    nba_players_without_current_team: ["NBA Roll Call Without a Current Team", "Learn players with an NBA roster entry and no current team recorded.",
      ->(players, _) { players.where(team_id: nil, id: cohorts.roster_entries("NBA").select(:player_id)) }]
  }

  variants.each do |key, (title, copy, filter)|
    quest_factory = :"#{key}_quest"

    factory quest_factory, parent: :quest do
      name { title }
      description { copy }

      transient do
        player_scope { Player.all }
        as_of { Date.current }
      end

      to_create do |quest, evaluator|
        cohort = filter.call(evaluator.player_scope, evaluator.as_of)
        player_ids = cohort.reorder(:id).distinct.pluck(:id)
        raise ArgumentError, "No catalog players match #{quest.name} on #{evaluator.as_of}" if player_ids.empty?

        Quest.transaction(requires_new: true) do
          quest.save!
          group = PlayerGroup.create!(name: quest.name, description: quest.description, player_ids: player_ids)
          achievement = FactoryBot.create(:achievement, name: quest.name, description: quest.description, target: group)
          FactoryBot.create(:highlight, quest: quest, achievement: achievement, position: 1, required: true)
        end
      end
    end

    factory :"#{key}_goal", parent: :goal do
      transient do
        player_scope { Player.all }
        as_of { Date.current }
      end

      quest { association quest_factory, player_scope: player_scope, as_of: as_of }
    end
  end
end
