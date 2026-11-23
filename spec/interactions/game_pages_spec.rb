require 'rails_helper'

RSpec.describe "Game pages" do
  let(:ace) { create(:ace) }
  let(:conference) { create(:conference) }
  let(:league) { conference.league }
  let(:divisions) { create_list(:division, 2, conference: conference) }
  let!(:teams) do
    Array.new(4) do |index|
      create(:team, league: league).tap do |team|
        create(:player, team: team)
        create(:membership, team: team, division: divisions[index % 2])
      end
    end
  end

  before { sign_in ace }

  context "without JavaScript" do

    it "asks which team a player plays for" do
      visit strength_team_match_path(league_id: league.id)

      expect(page).to have_css(".game-container .subject-card")
      expect(page).to have_content("Who does")
      expect(page).to have_css("[data-game-target='answerChoice']", count: 4)
      expect(page).to have_css("[data-game-target='progressCounter']", text: "0")
    end

    it "asks which division a team is in" do
      visit new_division_game_path

      expect(page).to have_content("Which division")
      expect(page).to have_css("[data-game-target='answerChoice']", minimum: 2)
    end

    it "links from a team to its quiz" do
      visit teams_path
      click_link "Quiz Me", match: :first
      expect(page).to have_button("Start round")
      click_button "Start round"
      expect(page).to have_css(".round-subject")
    end

    it "lists teams with attempts on the stats page" do
      attempt = create(:game_attempt, ace: ace, subject_entity: teams.first.players.first)

      visit strength_game_attempts_path

      expect(page).to have_content("By team, weakest first")
      click "a[href='#{team_strength_game_attempts_path(attempt.target_entity)}']"
      expect(page).to have_content(attempt.subject_entity.full_name)
    end
  end

  context "with JavaScript" do
    it "shows initials when a player's portrait fails to load and the portrait once it loads" do
      teams.each { |team| team.players.each { |player| player.update!(photo_urls: [ "/missing-player-portrait.png" ]) } }
      visit strength_team_match_path(league_id: league.id)
      find(".subject-card .entity-avatar img", visible: :all).execute_script("this.dispatchEvent(new Event('error'))")
      expect(page).to have_css(".subject-card .entity-avatar[data-image-state=fallback] .entity-initials")

      teams.each { |team| team.players.each { |player| player.update!(photo_urls: [ "/icon.png" ]) } }
      visit strength_team_match_path(league_id: league.id)
      find(".subject-card .entity-avatar img", visible: :all).execute_script("this.dispatchEvent(new Event('load'))")
      expect(page).to have_css(".subject-card .entity-avatar[data-image-state=loaded] .entity-portrait")
    end

    it "pauses with SVG controls and labels wrong and correct answers" do
      visit strength_team_match_path(league_id: league.id)
      click_button "Pause"
      expect(page).to have_css(".pause-button-main[aria-pressed=true] .resume-symbol")
      expect(page).to have_no_css("[data-game-target='answerChoice']:not([disabled])")
      click_button "Resume"

      find("[data-game-target='answerChoice'][data-correct=false]", match: :first).click
      expect(page).to have_css(".incorrect-choice .choice-status-incorrect", text: "Incorrect")
      expect(page).to have_css(".correct-answer .choice-status-correct", text: "Correct")

      travel 3.seconds # The next question follows the answer overlay.
      find("[data-game-target='answerChoice'][data-correct=true]").click
      expect(page).to have_css("[data-game-target='progressCounter']", text: "1")
      expect(page).to have_css(".correct-choice .choice-status-correct", text: "Correct")
    end

    # Answers the question on screen and returns the player it asked about.
    def answer_current_question
      player = Player.find(find("[data-game-target='questionCard']")["data-player-id"])
      first("[data-game-target='answerChoice']").click
      travel 3.seconds
      player
    end

    it "records each answer against the question that was on screen" do
      visit strength_team_match_path(league_id: league.id)
      first_player = answer_current_question
      expect(GameAttempt.last).to have_attributes(subject_entity: first_player, target_entity: first_player.team)

      second_player = answer_current_question
      attempt = GameAttempt.order(:id).last
      expect(attempt).to have_attributes(subject_entity: second_player, target_entity: second_player.team)
      expect(attempt.is_correct).to eq(attempt.chosen_entity == second_player.team)
    end
  end
end
