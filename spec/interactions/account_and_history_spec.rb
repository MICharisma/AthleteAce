require "rails_helper"

RSpec.describe "Account and history pages" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team, territory: "New York", mascot: "Yankees") }
  let(:player) { create(:player, team: team, first_name: "Aaron", last_name: "Judge") }

  it "keeps the player destination through account help and a failed sign-in" do
    visit player_path(player)
    click_link "Sign In", match: :first
    click_link "Create an account"
    expect(page).to have_field("Confirm password")
    within(".account-links") { click_link "Sign in" }
    click_link "Forgot your password?"
    expect(page).to have_button("Send reset instructions")
    within(".account-links") { click_link "Sign in" }

    fill_in "Email", with: ace.email
    fill_in "Password", with: "wrong-password"
    within(".account-form") { click_button "Sign in" }
    expect(page).to have_content("Invalid email or password.")
    fill_in "Password", with: "password123"
    within(".account-form") { click_button "Sign in" }
    expect(page).to have_current_path(player_path(player))
    expect(page).to have_css("h1", text: /Aaron Judge/i)
  end

  context "with a week of Team Match history" do
    let(:rival) { create(:team, territory: "Boston", mascot: "Red Sox", league: team.league) }
    let(:division) { create(:division, name: "American League East") }

    before do
      create(:player, team: create(:team, league: team.league))
      [ 6, 5, 3, 2, 1, 0 ].each do |days_ago|
        create(:game_attempt, ace: ace, subject_entity: player, created_at: days_ago.days.ago)
        create(:game_attempt, ace: ace, subject_entity: player, chosen_entity: rival, is_correct: false, created_at: days_ago.days.ago) unless days_ago == 2
      end
      create(:game_attempt, ace: ace, subject_entity: create(:player, team: rival), chosen_entity: team, is_correct: false)
      create(:game_attempt, ace: ace, subject_entity: player, created_at: 8.days.ago)
      create(:game_attempt, ace: ace, game_type: "guess_the_division", subject_entity: team, target_entity: division, chosen_entity: division)
      sign_in ace
      visit strength_game_attempts_path
    end

    it "counts the week's mix-ups and explains a day's results" do
      expect(page).to have_content("6 mix-ups")
      all(".history-chart-point").last.click
      expect(page).to have_css(".history-chart-point [role=tooltip]", text: "2 of 4 correct")
    end

    it "filters by game and keeps the filter on a team's history" do
      select "Guess the Division", from: "Game"
      click_button "Apply"
      expect(page).to have_css(".history-attempt", count: 1)
      expect(page).to have_no_content("Teams you mix up")
      within(".history-tabs") { click_link "By team" }
      click_link "New York Yankees 1 of 1 correct 100%"
      expect(page).to have_current_path(team_strength_game_attempts_path(team, game_type: "guess_the_division"))
      expect(page).to have_css(".history-attempt", count: 1)
      expect(page).to have_link("Practice Team Match", href: new_game_round_path(team_id: team.id))
    end

    it "keeps a mix-up drill to the two confused teams across rounds" do
      click "a[aria-label='Drill New York Yankees and Boston Red Sox']"
      click_button "Start round"
      expect(all(".round-choice").map { |choice| choice[:value] }).to contain_exactly(team.id, rival.id)
      first(".round-choice").click
      travel 2.seconds # Team Match advances 1.5 seconds after showing the answer.
      expect(page).to have_css(".round-game-progress", text: "2 / 2")
      expect(page).to have_css(".round-choice:not([disabled])", count: 2)
      expect(all(".round-choice").map { |choice| choice[:value] }).to contain_exactly(team.id, rival.id)
    end
  end
end
