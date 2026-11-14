require "rails_helper"

RSpec.describe "Team learning games" do
  let(:ace) { create(:ace) }
  let(:baseball) { create(:sport, name: "Baseball") }
  let(:mlb) { create(:league, sport: baseball, name: "Major League Baseball", abbreviation: "MLB") }
  let(:npb) { create(:league, sport: baseball, name: "Nippon Professional Baseball", abbreviation: "NPB") }
  let(:basketball) { create(:sport, name: "Basketball") }
  let(:nba) { create(:league, sport: basketball, name: "National Basketball Association", abbreviation: "NBA") }
  let!(:yankees) { create(:team, league: mlb, territory: "New York", mascot: "Yankees") }
  let!(:giants) { create(:team, league: npb, territory: "Yomiuri", mascot: "Giants") }
  let!(:knicks) { create(:team, league: nba, territory: "New York", mascot: "Knicks") }

  it "asks only about selected teams, using other leagues in their sport as choices" do
    setup = GameRoundSetup.new(game_type: "guess_the_league", team_id: yankees.id, length: 20)
    expect(setup.available_count).to eq(1)
    round = setup.start!(ace)
    expect(round.length).to eq(1)
    expect(round.scope).to include("team_id" => yankees.id, "length" => 20)
    expect(round.question).to include("subject_type" => "Team", "subject_id" => yankees.id, "team_id" => yankees.id,
      "target_type" => "League", "target_id" => mlb.id, "target_name" => mlb.name)
    expect(round.question.fetch("choices").map { |choice| choice.fetch("id") }).to match_array([ mlb.id, npb.id ])
  end

  it "offers sports outside the question scope without asking about outside teams" do
    round = GameRoundSetup.new(game_type: "guess_the_sport", sport_id: baseball.id).start!(ace)
    expect(round.length).to eq(2)
    expect(round.questions.map { |question| question.fetch("subject_id") }).to match_array([ yankees.id, giants.id ])
    round.questions.each do |question|
      expect(question).to include("target_type" => "Sport", "target_id" => baseball.id)
      expect(question.fetch("choices").map { |choice| choice.fetch("id") }).to match_array([ baseball.id, basketball.id ])
    end
  end

  it "does not require players or divisions and preserves snapshots after a team changes leagues" do
    round = GameRoundSetup.new(game_type: "guess_the_league", team_id: yankees.id).start!(ace)
    question = round.question
    yankees.update!(league: npb)
    round.answer!(at: 0, choice_id: mlb.id)
    expect(round.current_attempt).to be_correct
    expect(round.reload.question).to eq(question)
    expect(round.current_attempt.target_entity).to eq(mlb)
    expect(GameHistory.new(ace: ace, team: yankees).attempts).to contain_exactly(round.current_attempt)
  end

  it "honors group progress and explicit player filters using their current teams" do
    judge = create(:player, team: yankees, first_name: "Aaron", last_name: "Judge", active: false)
    group = PlayerGroup.create!(name: "New York favorites", players: [ judge ])
    setup = GameRoundSetup.new(game_type: "guess_the_sport", player_group_id: group.id, ace: ace)
    expect(setup.subjects).to contain_exactly(yankees)
    expect(GameRoundSetup.new(game_type: "guess_the_league", player_ids: [ judge.id ]).subjects).to contain_exactly(yankees)
    expect(GameRoundSetup.new(game_type: "guess_the_sport", player_id: judge.id).subjects).to contain_exactly(yankees)
    create(:game_attempt, ace: ace, subject_entity: judge, target_entity: yankees)
    remaining = GameRoundSetup.new(game_type: "guess_the_sport", player_group_id: group.id, practice_filter: "remaining", ace: ace)
    expect(remaining.available_count).to eq(0)
  end

  it "refuses unplayable leagues and sports instead of adding unrelated questions or answer-only records" do
    create(:league, sport: basketball, name: "Women's National Basketball Association")
    expect(GameRoundSetup.new(game_type: "guess_the_league", team_id: knicks.id).available_count).to eq(0)
    expect { GameRoundSetup.new(game_type: "guess_the_league", team_id: knicks.id).start!(ace) }
      .to raise_error(ActiveModel::ValidationError, /No playable questions/)
    knicks.destroy!
    create(:sport, name: "Hockey")
    expect(GameRoundSetup.new(game_type: "guess_the_sport").available_count).to eq(0)
  end

  it "keeps identical displayed answer names from becoming duplicate options" do
    duplicate = create(:league, sport: baseball, name: " major league baseball ")
    create(:team, league: duplicate)
    duplicate_sport = create(:sport, name: " baseball ")
    create(:team, league: create(:league, sport: duplicate_sport))
    %w[guess_the_league guess_the_sport].each do |mode|
      round = GameRoundSetup.new(game_type: mode, team_id: yankees.id).start!(ace)
      names = round.question.fetch("choices").map { |choice| choice.fetch("name").squish.downcase }
      expect(names.uniq).to eq(names)
      expect(names.size).to eq(2)
    end
  end

  it "limits a round to its requested size with unique subjects and at most six choices" do
    7.times do |index|
      league = create(:league, sport: baseball, name: "Regional League #{index + 1}")
      create(:team, league: league)
    end
    create_list(:team, 5, league: mlb)
    round = GameRoundSetup.new(game_type: "guess_the_league", sport_id: baseball.id).start!(ace)
    expect(round.length).to eq(10)
    expect(round.questions.map { |question| question.fetch("subject_id") }.uniq.size).to eq(10)
    round.questions.each do |question|
      ids = question.fetch("choices").map { |choice| choice.fetch("id") }
      expect(ids.size).to eq(6)
      expect(ids.uniq).to eq(ids)
      expect(ids).to include(question.fetch("target_id"))
    end
  end

  %w[guess_the_league guess_the_sport].each do |mode|
    it "reuses #{mode} misses in due reviews and skips deleted choices" do
      original = GameRoundSetup.new(game_type: mode, team_id: yankees.id).start!(ace)
      original.answer!(at: 0, choice_id: nil)
      ace.practice_reviews.update_all(due_at: 1.minute.ago)
      review = GameRoundSetup.new(game_type: "phased_repetition").start!(ace)
      expect(review.question).to include("game_type" => mode, "target_type" => original.question.fetch("target_type"))
      review.answer!(at: 0, choice_id: review.question.fetch("target_id"))
      expect(review.current_attempt).to be_correct
      review.advance!(at: 0)
      expect(review).to be_completed
      ace.practice_reviews.update_all(due_at: 1.minute.ago)
      if mode == "guess_the_league"
        giants.destroy!
        npb.destroy!
      else
        knicks.destroy!
        nba.destroy!
        basketball.destroy!
      end
      expect(GameRoundSetup.new(game_type: "phased_repetition").available_count).to eq(0)
    end
  end
end
