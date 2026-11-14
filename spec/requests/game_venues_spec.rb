require "rails_helper"

RSpec.describe "Game venues", type: :request do
  let(:league) { create(:league) }
  let(:season) { create(:season, league: league) }
  let(:arena) { create(:stadium, name: "Climate Pledge Arena") }
  let(:helsinki) do
    finland = Country.create!(name: "Finland", abbreviation: "FI")
    uusimaa = State.create!(name: "Uusimaa", abbreviation: "18", country: finland)
    Stadium.create!(name: "Veikkaus Arena", city: City.create!(name: "Helsinki", state: uusimaa))
  end
  let(:home) { Campaign.create!(team: create(:team, league: league, stadium: arena), season: season) }
  let(:away) { Campaign.create!(team: create(:team, league: league), season: season) }

  def game(stadium: nil)
    Game.create!(name: "CAR at SEA", context: league, season: season, stadium: stadium).tap do |record|
      Contestant.create!(contest: record, campaign: home, side: "home")
      Contestant.create!(contest: record, campaign: away, side: "away")
    end
  end

  it "shows a recorded venue abroad and an inferred home venue on the public game page" do
    get game_path(game(stadium: helsinki))
    expect(response.body).to include("Veikkaus Arena · Helsinki, Uusimaa, Finland", "Away from the home team&#39;s venue (Climate Pledge Arena)")

    get game_path(game)
    expect(response.body).to include("Climate Pledge Arena", "Home team&#39;s venue; this game&#39;s venue is not recorded")
  end

  it "shows the venue and each entry's side on the admin game page" do
    sign_in create(:ace, :admin)
    get admin_game_path(game(stadium: helsinki))
    expect(response.body).to include("Veikkaus Arena · Helsinki, Uusimaa, Finland", "#{home.name} · #{season.name} · Home", "#{away.name} · #{season.name} · Away")
  end
end
