class TeamFactRound
  attr_reader :teams

  def initialize(teams:, game_type:)
    @game_type = game_type
    leagues = League.where(id: Team.select(:league_id)).includes(:sport).to_a
    @leagues_by_sport = leagues.group_by(&:sport_id)
    @sports = leagues.map(&:sport).uniq(&:id)
    @teams = teams.select { |team| target_for(team).name.present? && alternatives_for(team).any? }
  end

  def available_count
    teams.size
  end

  def questions(length:)
    teams.sample(length).map do |team|
      target = target_for(team)
      choices = (alternatives_for(team).sample(5) + [ target ]).shuffle
      { game_type: @game_type, subject_type: "Team", subject_id: team.id, subject_name: team.name, team_id: team.id,
        target_type: target.class.name, target_id: target.id, target_name: target.name,
        choices: choices.map { |choice| { id: choice.id, name: choice.name } } }
    end
  end

  private

  def target_for(team)
    @game_type == "guess_the_league" ? team.league : team.sport
  end

  def alternatives_for(team)
    pool = @game_type == "guess_the_league" ? @leagues_by_sport.fetch(team.league.sport_id) : @sports
    name = target_for(team).name.squish.downcase
    pool.select { |target| target.name.present? && target.name.squish.downcase != name }
      .uniq { |target| target.name.squish.downcase }
  end
end
