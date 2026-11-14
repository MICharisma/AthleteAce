require "rails_helper"

RSpec.describe "Team learning games", type: :system do
  let(:ace) { create(:ace) }
  let(:baseball) { create(:sport, name: "Baseball") }
  let(:mlb) { create(:league, sport: baseball, name: "Major League Baseball", abbreviation: "MLB") }

  before do
    create(:team, league: mlb, territory: "New York", mascot: "Yankees")
    create(:team, league: create(:league, sport: baseball, name: "Nippon Professional Baseball", abbreviation: "NPB"), territory: "Yomiuri", mascot: "Giants")
    create(:team, league: create(:league, sport: create(:sport, name: "Basketball"), name: "National Basketball Association", abbreviation: "NBA"), territory: "New York", mascot: "Knicks")
    sign_in ace
  end

  after { page.driver.browser.execute_cdp "Emulation.clearDeviceMetricsOverride" }

  %w[guess_the_league guess_the_sport].each do |mode|
    it "plays #{mode} with keyboard answers, pause/resume, saved feedback and a misses drill" do
      visit strength_path
      click_link GameRound::GAMES.fetch(mode)
      choose "Baseball"
      expect(page).to have_content("2 teams available")
      expect(page).not_to have_select("Roster season")
      page.save_screenshot Rails.root.join("tmp/screenshots/#{mode}-setup-desktop.png")
      click_button "Start round"
      expect(page).to have_css(".round-game-progress", text: "1 / 2")
      round = ace.game_rounds.last
      prompt = mode == "guess_the_league" ? /Which league is this team in\?/i : /Which sport does this team play\?/i
      expect(page).to have_css(".round-question-prompt", text: prompt)
      expect(page).to have_css(".round-choice-name", count: 2)
      page.driver.browser.execute_cdp "Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: false
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      page.save_screenshot Rails.root.join("tmp/screenshots/#{mode}-question-mobile.png")

      question = round.questions.first
      index = question.fetch("choices").index { |choice| choice.fetch("id") == question.fetch("target_id") }
      find(".round-subject h1").send_keys((index + 1).to_s)
      expect(page).to have_css(".round-feedback", text: /Correct/i)
      page.refresh
      expect(page).to have_css(".round-feedback", text: /Correct/i)
      find(".round-feedback").send_keys :enter
      expect(page).to have_css(".round-game-progress", text: "2 / 2")
      click_button "Pause round"
      click_button "Resume round"
      expect(page).to have_css(".round-game-progress", text: "2 / 2")
      click_button "I don’t know — show me"
      expect(page).to have_css(".round-feedback", text: /Not quite/i)
      page.execute_script("document.documentElement.dataset.theme = 'dark'")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      page.save_screenshot Rails.root.join("tmp/screenshots/#{mode}-feedback-dark-mobile.png")
      click_button "Round summary"
      expect(page).to have_css("h1", text: /Round complete/i)
      expect(page).to have_content("1 / 2")
      expect(page).to have_css(".round-result", count: 2)
      click_button "Drill misses"
      expect(page).to have_css(".round-game-progress", text: "1 / 1")
      expect(page).to have_css(".round-subject h1", text: /#{Regexp.escape(round.questions.last.fetch('subject_name'))}/i)
      expect(ace.game_attempts.count).to eq(2)
    end
  end
end
