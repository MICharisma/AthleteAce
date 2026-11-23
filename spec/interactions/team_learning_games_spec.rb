require "rails_helper"

RSpec.describe "Team learning games" do
  let(:ace) { create(:ace) }
  let(:baseball) { create(:sport, name: "Baseball") }
  let(:mlb) { create(:league, sport: baseball, name: "Major League Baseball", abbreviation: "MLB") }

  before do
    create(:team, league: mlb, territory: "New York", mascot: "Yankees")
    create(:team, league: create(:league, sport: baseball, name: "Nippon Professional Baseball", abbreviation: "NPB"), territory: "Yomiuri", mascot: "Giants")
    create(:team, league: create(:league, sport: create(:sport, name: "Basketball"), name: "National Basketball Association", abbreviation: "NBA"), territory: "New York", mascot: "Knicks")
    sign_in ace
  end

  { "guess_the_league" => /Which league is this team in\?/i, "guess_the_sport" => /Which sport does this team play\?/i }.each do |mode, prompt|
    context GameRound::GAMES.fetch(mode) do
      let(:round) { ace.game_rounds.last }

      def start_round(mode)
        visit strength_path
        click_link GameRound::GAMES.fetch(mode)
        choose "Baseball"
        click_button "Start round"
      end

      def answer_first_by_key
        question = round.questions.first
        find(".round-subject h1").send_keys((question.fetch("choices").index { |choice| choice.fetch("id") == question.fetch("target_id") } + 1).to_s)
      end

      it "asks about a sport's teams with two choices" do
        visit strength_path
        click_link GameRound::GAMES.fetch(mode)
        choose "Baseball"
        expect(page).to have_content("2 teams available")
        expect(page).to have_no_field("Roster season")
        click_button "Start round"
        expect(page).to have_css(".round-game-progress", text: "1 / 2")
        expect(page).to have_css(".round-question-prompt", text: prompt)
        expect(page).to have_css(".round-choice-name", count: 2)
      end

      it "answers with a number key, keeps the feedback through a refresh and advances with Enter" do
        start_round mode
        answer_first_by_key
        expect(page).to have_css(".round-feedback", text: /Correct/i)
        refresh
        expect(page).to have_css(".round-feedback", text: /Correct/i)
        find(".round-feedback").send_keys :enter
        expect(page).to have_css(".round-game-progress", text: "2 / 2")
      end

      it "keeps its place through a pause" do
        start_round mode
        answer_first_by_key
        find(".round-feedback").send_keys :enter
        click_button "Pause round"
        click_button "Resume round"
        expect(page).to have_css(".round-game-progress", text: "2 / 2")
      end

      it "summarizes the round and drills the miss" do
        start_round mode
        answer_first_by_key
        find(".round-feedback").send_keys :enter
        click_button "I don’t know — show me"
        click_button "Round summary"
        expect(page).to have_content("1 / 2")
        expect(page).to have_css(".round-result", count: 2)
        click_button "Drill misses"
        expect(page).to have_css(".round-game-progress", text: "1 / 1")
        expect(page).to have_css(".round-subject h1", text: /#{Regexp.escape(round.questions.last.fetch('subject_name'))}/i)
        expect(ace.game_attempts.count).to eq(2)
      end
    end
  end
end
