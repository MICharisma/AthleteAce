# True/false: is this player on the focus team? Mixes roster members with
# league decoys so the answer is not the same every time.
class OnTheTeamRound
  attr_reader :focus_team, :members, :decoys

  def initialize(focus_team:, members:, decoys:)
    @focus_team = focus_team
    @members = focus_team ? members.select { |player| player.team_id == focus_team.id } : []
    @decoys = focus_team ? decoys.reject { |player| player.team_id == focus_team.id } : []
    @league_teams = focus_team ? focus_team.league.teams.where.not(id: focus_team.id).to_a : []
  end

  def available_count
    return 0 unless focus_team && @league_teams.any? && @members.any? && @decoys.any?

    @members.size + @decoys.size
  end

  def questions(length:)
    return [] if available_count.zero?

    yes_count = [ length, @members.size ].min
    yes_count = [ yes_count, (length / 2.0).ceil ].min if @decoys.any?
    no_count = [ length - yes_count, @decoys.size ].min
    yes_count = [ length - no_count, @members.size ].min if yes_count + no_count < length && @members.size > yes_count

    picks = @members.sample(yes_count).map { |player| [ player, true ] } +
      @decoys.sample(no_count).map { |player| [ player, false ] }
    picks.shuffle.map { |player, on_team| question_for(player, on_team) }
  end

  private

  def question_for(player, on_team)
    decoy = @league_teams.sample
    yes = { id: focus_team.id, name: "Yes" }
    no = { id: decoy.id, name: "No" }
    {
      game_type: "on_the_team",
      subject_type: "Player",
      subject_id: player.id,
      subject_name: player.display_name,
      subject_photo_url: player.photo_url,
      subject_position: player.current_position.presence,
      subject_jersey_number: JerseyNumberLookup.new(player: player, team: player.team).call&.number,
      focus_team_id: focus_team.id,
      focus_team_name: focus_team.name,
      team_id: focus_team.id,
      on_team: on_team,
      correct_choice_id: on_team ? yes.fetch(:id) : no.fetch(:id),
      target_type: "Team",
      target_id: focus_team.id,
      target_name: on_team ? "Yes" : "No",
      choices: [ yes, no ].shuffle
    }
  end
end
