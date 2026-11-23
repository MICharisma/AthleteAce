require "rails_helper"

RSpec.describe "Saved rounds" do
  let(:ace) { create(:ace) }
  let(:sport) { create(:sport, name: "Baseball") }
  let(:league) { create(:league, name: "Major League Baseball", abbreviation: "MLB", sport: sport) }
  let(:conference) { create(:conference, league: league) }
  let(:team) { create(:team, territory: "New York", mascot: "Yankees", abbreviation: "NYY", league: league) }
  let(:rival) { create(:team, territory: "Boston", mascot: "Red Sox", abbreviation: "BOS", league: league) }
  let(:round) { ace.game_rounds.last }

  before do
    create(:membership, team: team, division: create(:division, name: "American League East", abbreviation: "AL East", conference: conference))
    create(:membership, team: rival, division: create(:division, name: "American League West", abbreviation: "AL West", conference: conference))
    create(:player, team: team, first_name: "Aaron", last_name: "Judge", active: true)
    create(:player, team: rival, first_name: "Rafael", last_name: "Devers", active: true)
    sign_in ace
  end

  def answer(position, correct: true)
    question = round.questions[position]
    choice = correct ? question.fetch("target_id") : question.fetch("choices").map { |item| item.fetch("id") }.find { |id| id != question.fetch("target_id") }
    find(".round-choice[value='#{choice}']").click
  end

  def start_league_round
    visit new_game_round_path(league_id: league.id)
    click_button "Start round"
  end

  it "shows the answer, then advances on its own after 1.5 seconds" do
    start_league_round
    answer 0
    expect(page).to have_css(".round-feedback", text: /Correct/i)
    expect(page).to have_css(".round-game-progress", text: "1 / 2")
    travel 2.seconds
    expect(page).to have_css(".round-game-progress", text: "2 / 2")
    expect(page).to have_no_button("Next")
  end

  it "stops the advance timer while a round is paused" do
    start_league_round
    answer 0
    travel 2.seconds
    click_button "I don’t know — show me"
    click_button "Pause round"
    travel 2.seconds
    expect(page).to have_button("Resume round")
    expect(round.reload.position).to eq(1)
    expect(round).not_to be_completed

    click_button "Resume round"
    expect(page).to have_css(".round-feedback", text: /Not quite/i)
    travel 2.seconds
    expect(page).to have_css("h1", text: /Round complete/i)
    expect(round.reload).to be_completed
    expect(round.game_attempts.count).to eq(2)
  end

  it "narrows round setup to the chosen sport and league" do
    create(:team, league: create(:league, name: "Basketball League", sport: create(:sport, name: "Basketball")))
    visit strength_path
    click_link "Pick game & scope"
    choose "Baseball"
    expect(all("#league_id option", visible: :all).map(&:text)).to eq([ "All baseball leagues", "Major League Baseball" ])
    select "Major League Baseball", from: "League"
    expect(page).to have_content("2 players available")
    expect(page).to have_content("This round will have 2 questions")
  end

  it "keeps an answered question and its questions through a refresh, a pause and a return from Play" do
    start_league_round
    snapshot = round.questions
    answer 0, correct: false
    expect(page).to have_css(".round-choice-wrong", count: 1)
    expect(page).to have_css(".round-miss-count", text: "Missed 1×")
    refresh
    expect(page).to have_css(".round-feedback", text: /Not quite/i)
    expect(round.game_attempts.count).to eq(1)

    click_button "Pause round"
    visit strength_path
    expect(page).to have_content("1 of 2 answered")
    within(".round-continue") { click_link "Continue" }
    click_button "Resume round"
    expect(page).to have_css(".round-game-progress", text: "1 / 2")
    expect(page).to have_css(".round-feedback", text: /Not quite/i)
    expect(round.reload.questions).to eq(snapshot)
  end

  it "answers with a number key, summarizes the round and drills only the misses" do
    start_league_round
    missed = round.questions.first.fetch("subject_name")
    answer 0, correct: false
    travel 2.seconds
    target = round.questions[1].fetch("target_id")
    key = round.questions[1].fetch("choices").index { |choice| choice.fetch("id") == target } + 1
    find(".round-subject h1").send_keys(key.to_s)
    expect(page).to have_css(".round-feedback", text: /Correct/i)
    travel 2.seconds
    expect(page).to have_css("h1", text: /Round complete/i)
    expect(page).to have_content("1 / 2")
    expect(page).to have_css(".round-result", count: 2)

    click_button "Drill misses"
    expect(page).to have_css(".round-game-progress", text: "1 / 1")
    expect(page).to have_css(".round-subject", text: /#{Regexp.escape(missed)}/i)
    click_button "I don’t know — show me"
    travel 2.seconds
    expect(page).to have_css("h1", text: /Round complete/i)
    expect(page).to have_content("0 / 1")
    expect(ace.game_attempts.count).to eq(3)
  end

  it "plays Guess the Division through the same saved round and summary" do
    visit new_game_round_path(game_type: "guess_the_division", league_id: league.id)
    expect(page).to have_content("2 teams available")
    click_button "Start round"
    expect(page).to have_content(/Which division is this team in\?/i)
    answer 0
    click_button "Next"
    answer 1
    click_button "Round summary"
    expect(page).to have_css("h1", text: /Round complete/i)
    expect(page).to have_content("2 / 2")
    expect(page).to have_no_button("Drill misses")
    click_link "Game history", match: :first
    expect(page).to have_css(".history-attempt", count: 2)
    expect(page).to have_link("View round", count: 2)
  end

  context "with a recorded photo that fails to load" do
    before do
      player = Player.joins(:figure).find_by!(figures: { first_name: "Aaron", last_name: "Judge" })
      player.update!(photo_urls: [ "/missing-athlete-photo.jpg" ], current_position: "Outfield")
      JerseyNumberAssignment.create!(player: player, team: team, number: "99", start_date: Date.current - 1.year)
      team.update!(primary_color: "#FFFFFF", secondary_color: "#003087")
      rival.update!(primary_color: "#000000", secondary_color: "#BD3039")
      visit new_game_round_path(team_id: team.id)
      click_button "Start round"
      find(".round-athlete-portrait img", visible: :all).execute_script("this.dispatchEvent(new Event('error'))")
    end

    it "shows the jersey number in place of the photo" do
      expect(page).to have_css('.round-athlete-portrait[data-image-state="fallback"] .round-jersey')
      expect(page).to have_css(".round-jersey .jersey-number", text: "99")
      expect(page).to have_css(".round-number-caption", text: "No. 99")
      expect(page).to have_css(".round-subject-details", text: "Outfield")
    end

    it "colors the portrait and answer badges from each team's palette" do
      expect(find(".round-athlete-portrait")[:style]).to include("--team-color: #FFFFFF", "--team-ink: #131418", "--team-secondary: #003087")
      expect(find(".round-choice[value='#{rival.id}'] .round-team-badge")[:style]).to include("--team-color: #000000", "--team-ink: #FFFFFF")
      expect(page).to have_css(".round-team-answer", count: 2)
      expect(page).to have_css(".round-answer-territory", text: "New York")
      expect(page).to have_css(".round-answer-club", text: "Yankees")
    end

    it "marks the wrong team and reveals the right one" do
      find(".round-choice[value='#{rival.id}']").click
      expect(page).to have_css(".round-miss-count", text: "Missed 1×")
      expect(page).to have_css(".round-choice-correct", count: 1)
      expect(page).to have_css(".round-choice-wrong", count: 1)
    end
  end
end
