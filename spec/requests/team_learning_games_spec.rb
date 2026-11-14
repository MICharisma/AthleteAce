require "rails_helper"

RSpec.describe "Team learning games", type: :request do
  let(:ace) { create(:ace) }
  let(:baseball) { create(:sport, name: "Baseball") }
  let(:mlb) { create(:league, sport: baseball, name: "Major League Baseball") }
  let!(:team) { create(:team, league: mlb, territory: "New York", mascot: "Yankees") }

  before do
    create(:team, league: create(:league, sport: baseball, name: "Nippon Professional Baseball"))
    create(:team, league: create(:league, sport: create(:sport, name: "Basketball"), name: "National Basketball Association"))
    sign_in ace
  end

  { "guess_the_league" => "Which league is this team in?", "guess_the_sport" => "Which sport does this team play?" }.each do |mode, prompt|
    it "plays #{mode} with server scoring, saved misses, replay and team history" do
      get strength_path
      expect(response.body).to include(new_game_round_path(game_type: mode))
      get new_game_round_path, params: { game_type: mode, team_id: team.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1 team available")
      post game_rounds_path, params: { game_type: mode, team_id: team.id }
      round = ace.game_rounds.last
      expect(response).to redirect_to(game_round_path(round))
      get game_round_path(round)
      expect(response.body).to include(prompt)
      expect(Nokogiri::HTML(response.body).css(".round-choice[data-correct]")).to be_empty

      post answer_game_round_path(round), params: { position: 0, choice_id: -1, is_correct: true }
      expect(round.game_attempts.count).to eq(0)
      wrong = round.question.fetch("choices").find { |choice| choice.fetch("id") != round.question.fetch("target_id") }
      post answer_game_round_path(round), params: { position: 0, choice_id: wrong.fetch("id"), is_correct: true }
      expect(round.current_attempt).not_to be_correct
      post answer_game_round_path(round), params: { position: 0, choice_id: round.question.fetch("target_id") }
      expect(round.game_attempts.count).to eq(1)
      expect(round.current_attempt).not_to be_correct
      post advance_game_round_path(round), params: { position: 0 }
      get summary_game_round_path(round)
      expect(response.body).to include("Round complete", "0 / 1", "Drill misses")
      get team_strength_game_attempts_path(team), params: { game_type: mode }
      expect(response.body).to include(GameRound::GAMES.fetch(mode), "View round", team.name)
      post drill_game_round_path(round)
      drill = ace.game_rounds.last
      expect(drill.game_type).to eq(mode)
      expect(drill.questions).to eq(round.questions)
      get new_game_round_path, params: { game_type: mode, team_id: team.id }
      expect(response.body).to include("Start round")
    end

    it "rejects #{mode} on the legacy attempt endpoint" do
      expect {
        post game_attempts_path, params: { game_attempt: { game_type: mode, subject_entity_type: "Team",
          subject_entity_id: team.id, chosen_entity_type: mode == "guess_the_league" ? "League" : "Sport",
          chosen_entity_id: mode == "guess_the_league" ? mlb.id : baseball.id } }, as: :json
      }.not_to change(GameAttempt, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
