require "rails_helper"

RSpec.describe "/achievements", type: :request do
  let(:team) { create(:team, territory: "Boston", mascot: "Celtics", abbreviation: "BOS") }
  let!(:rival) { create(:team, league: team.league) }
  let!(:players) { create_list(:player, 3, team: team) }
  let!(:rival_players) { create_list(:player, 3, team: rival) }
  let!(:achievement) do
    create(:achievement,
      name: "Celtics Roster Fluency",
      description: "Know key players from the Celtics roster.",
      target: team,
      roster_level: "fluency")
  end
  let!(:required_quest) { create(:quest, name: "Atlantic Division Run", description: "Master Atlantic rosters.") }
  let!(:required_highlight) { create(:highlight, quest: required_quest, achievement: achievement, required: true) }

  it "renders achievement details, stats, and session controls for signed-out visitors without admin actions or dimension picker" do
    create(:familiarity)

    get achievement_path(achievement)
    expect(response).to have_http_status(:ok)

    doc = response.parsed_body
    expect(doc.at_css("title").text).to eq("Celtics Roster Fluency")
    expect(doc.css("main h1").map(&:text)).to eq([ "Celtics Roster Fluency" ])
    expect(doc.at_css("#spectrum-picker")).to be_nil

    expect(doc.at_css(".entity-chip").text).to include(team.name)
    expect(doc.at_css('.quest-roster-level[data-roster-level="fluency"]').text).to eq("Roster fluency")

    stats = doc.css(".achievement-stats > div").to_h do |item|
      [ item.at_css("dt").text, item.at_css("dd").text ]
    end
    expect(stats).to eq("Players" => "15", "Quests" => "1", "Earned" => "0")

    session = doc.at_css(".quest-session.achievement-session")
    expect(session).to be_present
    expect(session.css(".quest-session-length").map(&:text)).to eq(%w[10 20 30])
    expect(session.at_css('.quest-session-length[aria-pressed="true"]').text).to eq("10")

    practice = session.at_css('a[aria-label="Practice Celtics Roster Fluency"]')
    expect(practice["href"]).to start_with(flash_cards_path)
    expect(Rack::Utils.parse_nested_query(URI.parse(practice["href"]).query)).to include(
      "team_id" => team.id.to_s, "include_inactive" => "true", "delay" => "5", "length" => "10"
    )

    arena = session.at_css('a[aria-label="Arena for Celtics Roster Fluency"]')
    expect(arena["href"]).to start_with(new_game_round_path)
    expect(Rack::Utils.parse_nested_query(URI.parse(arena["href"]).query)).to include(
      "team_id" => team.id.to_s, "include_inactive" => "true", "length" => "10"
    )

    test_form = session.css("form").find { |form| form.at_css('button.achievement-session-test[aria-label="Test Celtics Roster Fluency"]') }
    expect(test_form).to be_present
    expect(test_form["action"]).to eq(game_rounds_path)
    expect(test_form.at_css('input[name="game_type"]')["value"]).to eq("on_the_team")
    expect(test_form.at_css('input[name="team_id"]')["value"]).to eq(team.id.to_s)
    expect(test_form.at_css('input[name="length"]')["value"]).to eq("10")

    quest_row = doc.at_css(".achievement-quest-row")
    expect(quest_row.text).to include("Atlantic Division Run", "Master Atlantic rosters.", "Required")
    expect(quest_row.at_css('a.tool-button[href="' + quest_path(required_quest) + '"]').text).to eq("View quest")

    hrefs = doc.css("main a").map { |link| link["href"] }
    expect(hrefs).not_to include(edit_achievement_path(achievement), new_highlight_path(achievement_id: achievement.id))
    expect(doc.css("main form").map { |form| form["action"] }).not_to include(achievement_path(achievement))
  end

  it "shows personal goal progress, scopes session controls to the active goal, and renders quest actions for signed-in aces" do
    ace = create(:ace)
    goal = ace.adopt_quest(required_quest)
    season_id = SecureRandom.uuid_v7
    goal.goal_achievements.find_by!(achievement: achievement).update!(
      practice_scope: { team_id: team.id, season_id: season_id, include_inactive: true }
    )

    optional_quest = create(:quest, name: "Eastern Conference Tour", description: "Explore eastern teams.")
    create(:highlight, quest: optional_quest, achievement: achievement, required: false)

    sign_in ace
    get achievement_path(achievement)
    expect(response).to have_http_status(:ok)

    doc = response.parsed_body
    expect(doc.at_css(".achievement-progress").text).to include("Your progress", "0/15", "Tracked in Atlantic Division Run")
    expect(doc.at_css('.achievement-progress a[href="' + goal_path(goal) + '"]')).to be_present

    session = doc.at_css(".quest-session.achievement-session")
    practice = session.at_css('a[aria-label="Practice Celtics Roster Fluency"]')
    expect(Rack::Utils.parse_nested_query(URI.parse(practice["href"]).query)).to include(
      "team_id" => team.id.to_s, "season_id" => season_id, "include_inactive" => "true", "delay" => "5", "length" => "10"
    )
    arena = session.at_css('a[aria-label="Arena for Celtics Roster Fluency"]')
    expect(Rack::Utils.parse_nested_query(URI.parse(arena["href"]).query)).to include(
      "team_id" => team.id.to_s, "season_id" => season_id, "include_inactive" => "true", "length" => "10"
    )
    test_form = session.css("form").find { |form| form.at_css('button.achievement-session-test[aria-label="Test Celtics Roster Fluency"]') }
    expect(test_form.at_css('input[name="season_id"]')["value"]).to eq(season_id)

    rows = doc.css(".achievement-quest-row")
    expect(rows.size).to eq(2)

    adopted_row = rows.find { |row| row.text.include?("Atlantic Division Run") }
    expect(adopted_row.at_css('.achievement-quest-role[data-required="true"]').text).to eq("Required")
    expect(adopted_row.at_css('a[href="' + goal_path(goal) + '"]').text).to include("Continue Quest")

    optional_row = rows.find { |row| row.text.include?("Eastern Conference Tour") }
    expect(optional_row.at_css('.achievement-quest-role[data-required="false"]').text).to eq("Optional")
    expect(optional_row.at_css("form.button_to button").text).to include("Begin Quest")

    hrefs = doc.css("main a").map { |link| link["href"] }
    expect(hrefs).to include(new_highlight_path(achievement_id: achievement.id))
    expect(hrefs).not_to include(edit_achievement_path(achievement))
  end

  it "shows Edit and Delete controls only to admins" do
    sign_in create(:ace, :admin)
    get achievement_path(achievement)
    expect(response).to have_http_status(:ok)

    doc = response.parsed_body
    expect(doc.at_css('main a[href="' + edit_achievement_path(achievement) + '"]').text).to eq("Edit")
    delete_form = doc.css("main form").find { |form| form["action"] == achievement_path(achievement) && form.at_css('input[name="_method"][value="delete"]') }
    expect(delete_form).to be_present
  end

  it "renders non-playable achievements with no quests cleanly" do
    country = create(:country, name: "Canada")
    unplayable = create(:achievement, name: "Canadian Foundations", description: "Recognize Canadian sports roots.", target: country)

    get achievement_path(unplayable)
    expect(response).to have_http_status(:ok)

    doc = response.parsed_body
    expect(doc.at_css(".achievement-play-panel")).to be_nil
    expect(doc.at_css(".quest-session")).to be_nil
    expect(doc.text).to include("Not part of any quests yet.")
  end
end
