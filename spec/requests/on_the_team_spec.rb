require "rails_helper"

RSpec.describe "On the Team", type: :request do
  let(:ace) { create(:ace) }
  let(:league) { create(:league) }
  let(:team) { create(:team, league: league, territory: "Orlando", mascot: "Magic") }
  let!(:rival) { create(:team, league: league) }
  let!(:members) { create_list(:player, 3, team: team) }
  let!(:decoys) { create_list(:player, 3, team: rival) }

  before { sign_in ace }

  it "starts a yes/no round for one team" do
    expect {
      post game_rounds_path, params: { game_type: "on_the_team", team_id: team.id, length: 10, include_inactive: true }
    }.to change(GameRound, :count).by(1)

    round = ace.game_rounds.last
    expect(response).to redirect_to(game_round_path(round))
    expect(round.game_type).to eq("on_the_team")
    expect(round.questions).to all(include("game_type" => "on_the_team", "focus_team_id" => team.id))
    expect(round.questions.map { |question| question.fetch("on_team") }).to include(true, false)
  end

  it "scores yes and no from the focus team id" do
    round = GameRoundSetup.new(game_type: "on_the_team", team_id: team.id, length: 10, include_inactive: true).start!(ace)
    question = round.questions.first
    correct = question.fetch("choices").find { |choice| choice.fetch("id") == question.fetch("correct_choice_id") }

    expect {
      round.answer!(at: 0, choice_id: correct.fetch("id"))
    }.to change(GameAttempt, :count).by(1)
    expect(round.game_attempts.sole).to be_correct
    expect(round.game_attempts.sole.target_entity_id).to eq(team.id)
  end
end
