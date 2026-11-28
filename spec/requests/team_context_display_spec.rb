require "rails_helper"

RSpec.describe "Team context display for multi-team organizations", type: :request do
  let(:basketball) { create(:sport, name: "Basketball") }
  let(:football) { create(:sport, name: "Football") }
  let(:mens_hoops) { create(:league, sport: basketball, name: "NCAA Division I Men's Basketball", abbreviation: "NCAA D1 Men") }
  let(:womens_hoops) { create(:league, sport: basketball, name: "NCAA Division I Women's Basketball", abbreviation: "NCAA D1 Women") }
  let(:fcs_football) { create(:league, sport: football, name: "NCAA Division I FCS Football", abbreviation: "NCAA FCS") }
  let(:yale_org) { create(:organization, name: "Yale Athletics", abbreviation: "YALE") }

  let!(:yale_men) { create(:team, league: mens_hoops, territory: "Yale", mascot: "Bulldogs", abbreviation: "YALE") }
  let!(:yale_women) { create(:team, league: womens_hoops, territory: "Yale", mascot: "Bulldogs", abbreviation: "YALE") }
  let!(:yale_football) { create(:team, league: fcs_football, territory: "Yale", mascot: "Bulldogs", abbreviation: "YALE") }

  before do
    [ yale_men, yale_women, yale_football ].each do |team|
      create(:organization_affiliation, organization: yale_org, team: team)
    end
  end

  it "shows sorted league and sport context on organization pages and caps index pills" do
    get organizations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Yale Bulldogs · NCAA D1 Men · Basketball", "Yale Bulldogs · NCAA D1 Women · Basketball", "Yale Bulldogs · NCAA FCS · Football")

    get organization_path(yale_org)
    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    current_teams_section = doc.css("section").find { |section| section.at_css("h2")&.text == "Current Teams" }
    team_texts = current_teams_section.css("a p").map(&:text)
    expect(team_texts).to eq([
      "NCAA Division I Men's Basketball",
      "NCAA Division I Women's Basketball",
      "NCAA Division I FCS Football"
    ])

    big_org = create(:organization, name: "Big Athletics")
    10.times do |index|
      league = create(:league, sport: basketball, name: "League #{index + 1}", abbreviation: "LG#{index + 1}")
      team = create(:team, league: league, territory: "State", mascot: "Tigers #{index + 1}")
      create(:organization_affiliation, organization: big_org, team: team)
    end

    get organizations_path
    expect(response).to have_http_status(:ok)
    big_card = Nokogiri::HTML(response.body).css("a[href='#{organization_path(big_org)}']").first
    expect(big_card.text).to include("+2 more")
    expect(big_card.css("span.rounded-full").size).to eq(9)
  end

  it "includes league and sport subtitles for teams in shell search" do
    get search_path, params: { q: "Yale", side: "play" }, headers: { "X-Requested-With" => "XMLHttpRequest" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Team · NCAA D1 Men · Basketball", "Team · NCAA D1 Women · Basketball", "Team · NCAA FCS · Football")
  end

  it "disambiguates colliding teams in cross-league setup and omits extra labels inside a single league" do
    create(:player, team: yale_men, first_name: "John", last_name: "Poulakidas")
    create(:player, team: yale_women, first_name: "Kiley", last_name: "Capstraw")

    get new_game_round_path, params: { sport_id: basketball.id }
    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css("#round_team_#{yale_men.id}")["aria-label"]).to eq("Yale Bulldogs · NCAA D1 Men · Basketball")
    expect(doc.at_css("#round_team_#{yale_women.id}")["aria-label"]).to eq("Yale Bulldogs · NCAA D1 Women · Basketball")
    expect(response.body).to include("NCAA D1 Men · Basketball", "NCAA D1 Women · Basketball")

    get new_game_round_path, params: { sport_id: basketball.id, league_id: mens_hoops.id }
    expect(response).to have_http_status(:ok)
    single_doc = Nokogiri::HTML(response.body)
    expect(single_doc.at_css("#round_team_#{yale_men.id}")["aria-label"]).to eq("Yale Bulldogs")
  end

  it "disambiguates colliding teams in on_the_team, player_team_match, multiple_choice, and flash_cards" do
    ace = create(:ace)
    harvard_men = create(:team, league: mens_hoops, territory: "Harvard", mascot: "Crimson", abbreviation: "HARV")
    mens_player = create(:player, team: yale_men, first_name: "John", last_name: "Poulakidas")
    womens_player = create(:player, team: yale_women, first_name: "Kiley", last_name: "Capstraw")
    create(:player, team: harvard_men, first_name: "Robert", last_name: "Hinton")
    sign_in ace

    on_team_round = GameRoundSetup.new(game_type: "on_the_team", team_id: yale_men.id, length: 10).start!(ace)
    get game_round_path(on_team_round)
    expect(response.body).to include("Is this player on the Yale Bulldogs (NCAA D1 Men · Basketball)?")

    match_round = GameRoundSetup.new(game_type: "player_team_match", team_ids: [ yale_men.id, yale_women.id ], length: 10).start!(ace)
    get game_round_path(match_round)
    expect(response.body).to include("NCAA D1 Men · Basketball", "NCAA D1 Women · Basketball")

    mc_round = GameRoundSetup.new(game_type: "multiple_choice", fact_type: "team", team_ids: [ yale_men.id, yale_women.id ], length: 10).start!(ace)
    get game_round_path(mc_round)
    expect(response.body).to include("NCAA D1 Men · Basketball", "NCAA D1 Women · Basketball")

    get flash_cards_path, params: { team_ids: [ yale_men.id ] }
    expect(response).to have_http_status(:ok)
    flash_card_text = Nokogiri::HTML(response.body).at_css(".flash-card").text.squish
    expect(flash_card_text).to include(mens_player.name, "(NCAA D1 Men · Basketball)")

    get flash_cards_path, params: { team_ids: [ harvard_men.id ] }
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css(".flash-card").text.squish).not_to include("(NCAA D1 Men · Basketball)")
    expect(womens_player).to be_persisted
  end
end
