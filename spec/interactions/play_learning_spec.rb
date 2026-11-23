require "rails_helper"

RSpec.describe "Play learning" do
  let(:ace) { create(:ace) }
  let!(:team) { create(:team, territory: "New York", mascot: "Knicks", abbreviation: "NYK") }
  let!(:rival) { create(:team, league: team.league, territory: "Brooklyn", mascot: "Nets", abbreviation: "BKN") }
  let!(:player) { create(:player, team: team, first_name: "Jalen", last_name: "Brunson") }
  let!(:other_player) { create(:player, team: rival, first_name: "Nic", last_name: "Claxton") }

  context "with a quest on the Knicks roster" do
    let(:quest) { create(:quest, name: "New York names") }
    let(:round) { ace.game_rounds.last }

    before do
      quest.add_achievement(create(:achievement, name: "Learn the Knicks roster", target: team))
      ace.adopt_quest(quest)
      sign_in ace
    end

    def answer(position)
      find(".round-choice[value='#{round.questions[position]['target_id']}']").click
    end

    it "asks Multiple Choice questions about current teams" do
      visit new_game_round_path(game_type: "multiple_choice", league_id: team.league_id)
      expect(page).to have_select("Question topic", selected: "Current team")
      expect(page).to have_content("2 players available")
      click_button "Start round"
      expect(page).to have_css(".round-game-progress", text: "1 / 2")
    end

    it "keeps answer feedback through a pause and a refresh" do
      visit new_game_round_path(game_type: "multiple_choice", league_id: team.league_id)
      click_button "Start round"
      answer 0
      click_button "Pause round"
      refresh
      click_button "Resume round"
      expect(page).to have_css(".round-feedback", text: /Correct/i)
    end

    it "completes the quest when the round covers the whole roster" do
      visit new_game_round_path(game_type: "multiple_choice", league_id: team.league_id)
      click_button "Start round"
      answer 0
      click_button "Next"
      answer 1
      click_button "Round summary"
      expect(page).to have_content("2 / 2")
      expect(page).to have_content("Names newly known")
      visit quest_path(quest)
      expect(page).to have_content("Done")
      expect(ace.goals.sole.reload.status).to eq("completed")
      visit strength_path
      expect(page).to have_content(/Names known/i)
    end
  end

  it "plays a due review with the original question and records it under Phased Repetition" do
    round = GameRoundSetup.new(team_id: team.id).start!(ace)
    round.answer!(at: 0, choice_id: nil)
    ace.practice_reviews.update_all(due_at: 1.minute.ago)
    sign_in ace
    visit strength_path
    click_button "Review now"
    expect(page).to have_css(".round-game-bar", text: /Phased Repetition/i)
    expect(page).to have_content(/Jalen Brunson/i)
    find(".round-choice[value='#{team.id}']").click
    expect(page).to have_css(".round-feedback", text: /Correct/i)
    click_button "Round summary"
    expect(page).to have_content("1 / 1")
    visit strength_game_attempts_path(game_type: "phased_repetition")
    expect(page).to have_css(".history-attempt", count: 1)
  end

  it "shows a failed photo without leaking initials or accepting guesses" do
    [ player, other_player ].each { |record| record.update!(photo_urls: [ "/unavailable-player-photo.png" ]) }
    round = GameRoundSetup.new(game_type: "image_recognition").start!(ace)
    sign_in ace
    visit game_round_path(round)
    find(".round-subject img", visible: :all).execute_script("this.dispatchEvent(new Event('error'))")
    expect(page).to have_content("This photo could not load")
    expect(page).to have_css(".round-subject h1", text: /Who is this player\?/i)
    expect(page).to have_css('.round-choice:disabled', count: 2)
    expect(page).not_to have_css(".round-subject .round-jersey")
    expect(round.game_attempts.count).to eq(0)
  end

  it "lets a visitor try one question before sign-up" do
    visit feed_path
    click_link "Try"
    expect(page).to have_content(/Try one · Team Match/i)
    within(".round-choices") { first("button").click }
    expect(page).to have_content("Sign in to start saved rounds and track your streak")
    expect(GameAttempt.count).to eq(0)
    expect(GameRound.count).to eq(0)
    expect(page).to have_link("New here? Create a free account")
  end
end
