require 'rails_helper'

RSpec.describe "/goals", type: :request do
  let(:ace) { create(:ace) }
  let(:quest) { create(:quest) }
  let(:valid_attributes) { { ace: ace, quest: quest, status: 'in_progress', progress: 1 } }

  before do
    sign_in ace
  end

  describe "GET /index" do
    it "renders a successful response" do
      Goal.create! valid_attributes
      get goals_url
      expect(response).to be_successful
      expect(response.body).to include("My Goals")
    end

    it "displays goals grouped by status" do
      goal1 = Goal.create!(valid_attributes.merge(status: 'in_progress'))
      goal2 = Goal.create!(valid_attributes.merge(quest: create(:quest), status: 'completed'))
      
      get goals_url
      expect(response).to be_successful
      expect(response.body).to include("In Progress Goals")
      expect(response.body).to include("Completed Goals")
    end

    it "shows empty state when no goals exist" do
      get goals_url
      expect(response).to be_successful
      expect(response.body).to include("No goals yet")
      expect(response.body).to include("Browse Quests")
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      goal = Goal.create! valid_attributes
      get goal_url(goal)
      expect(response).to be_successful
      expect(response.body).to include(goal.quest.name)
    end

    it "renders scoped quest-style session buttons and hides the dimension picker" do
      create(:familiarity)
      team = create(:team)
      rival = create(:team, league: team.league)
      create_list(:player, 3, team: team)
      create_list(:player, 3, team: rival)
      achievement = create(:achievement, target: team, name: "Learn this roster", roster_level: "fluency")
      create(:highlight, quest: quest, achievement: achievement)
      goal = ace.adopt_quest(quest)
      season_id = SecureRandom.uuid_v7
      goal.goal_achievements.find_by!(achievement: achievement).update!(
        practice_scope: { team_id: team.id, season_id: season_id, include_inactive: true }
      )

      get goal_url(goal)
      expect(response).to be_successful
      doc = response.parsed_body

      expect(doc.at_css("#spectrum-picker")).to be_nil

      session = doc.at_css(".quest-session.goal-session")
      expect(session).to be_present
      expect(session.css(".quest-session-length").map(&:text)).to eq(%w[10 20 30])
      expect(session.at_css('.quest-session-length[aria-pressed="true"]').text).to eq("10")

      practice = session.at_css('a[aria-label="Practice Learn this roster"]')
      expect(practice["href"]).to start_with(flash_cards_path)
      expect(Rack::Utils.parse_nested_query(URI.parse(practice["href"]).query)).to include(
        "team_id" => team.id.to_s, "season_id" => season_id, "include_inactive" => "true", "delay" => "5", "length" => "10"
      )

      arena = session.at_css('a[aria-label="Arena for Learn this roster"]')
      expect(arena["href"]).to start_with(new_game_round_path)
      expect(Rack::Utils.parse_nested_query(URI.parse(arena["href"]).query)).to include(
        "team_id" => team.id.to_s, "season_id" => season_id, "include_inactive" => "true", "length" => "10"
      )

      test_form = session.css("form").find { |form| form.at_css('button.goal-session-test[aria-label="Test Learn this roster"]') }
      expect(test_form).to be_present
      expect(test_form["action"]).to eq(game_rounds_path)
      expect(test_form.at_css('input[name="game_type"]')["value"]).to eq("on_the_team")
      expect(test_form.at_css('input[name="team_id"]')["value"]).to eq(team.id.to_s)
      expect(test_form.at_css('input[name="season_id"]')["value"]).to eq(season_id)
      expect(test_form.at_css('input[name="length"]')["value"]).to eq("10")

      expect(doc.at_css(".achievement-name-link")["href"]).to eq(achievement_path(achievement))
      expect(doc.at_css('.quest-roster-level[data-roster-level="fluency"]').text).to eq("Roster fluency")
      expect(doc.at_css(".quest-roster-progress").text).to eq("0/15")
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested goal" do
      goal = Goal.create! valid_attributes
      expect {
        delete goal_url(goal)
      }.to change(Goal, :count).by(-1)
    end

    it "redirects to the quests list" do
      goal = Goal.create! valid_attributes
      delete goal_url(goal)
      expect(response).to redirect_to(quests_path)
    end
  end
end