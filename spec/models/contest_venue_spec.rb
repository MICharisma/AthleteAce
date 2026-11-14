require "rails_helper"
require "tmpdir"

RSpec.describe "Contest venues" do
  let(:league) { create(:league) }
  let(:season) { create(:season, league: league) }
  let(:home_arena) { create(:stadium, name: "Home Arena", entity_code: "STADIUM-HOME_ARENA") }
  let(:helsinki) { create(:stadium, name: "Veikkaus Arena", entity_code: "STADIUM-FI-18-HELSINKI-VEIKKAUS_ARENA") }
  let(:home_team) { create(:team, league: league, stadium: home_arena) }
  let(:away_team) { create(:team, league: league) }
  let(:home_campaign) { Campaign.create!(team: home_team, season: season) }
  let(:away_campaign) { Campaign.create!(team: away_team, season: season) }

  def game_between(stadium: nil, code: nil)
    game = Game.create!(name: "Away at Home", context: league, season: season, stadium: stadium, entity_code: code)
    home = Contestant.create!(contest: game, campaign: home_campaign, side: "home", entity_code: (code && "#{code}-HOME"))
    away = Contestant.create!(contest: game, campaign: away_campaign, side: "away", entity_code: (code && "#{code}-AWAY"))
    [ game, home, away ]
  end

  it "uses a recorded venue, else the home entry's season venue, else the team's" do
    game, = game_between
    expect([ game.venue, game.venue_basis ]).to eq([ home_arena, :home_venue ])
    expect(game.away_from_home_venue?).to be(false)

    season_arena = create(:stadium, name: "Temporary Arena")
    home_campaign.update!(stadium: season_arena)
    expect(game.reload.venue).to eq(season_arena)

    game.update!(stadium: helsinki)
    expect([ game.venue, game.venue_basis ]).to eq([ helsinki, :recorded ])
    expect(game.away_from_home_venue?).to be(true)
    expect(helsinki.hosted_contests).to eq([ game ])
    expect { helsinki.destroy }.not_to change(Stadium, :count)
  end

  it "leaves the venue unknown without a recorded venue or a home side" do
    game = Game.create!(name: "Neutral", context: league, season: season)
    Contestant.create!(contest: game, campaign: home_campaign)
    expect([ game.venue, game.venue_basis ]).to eq([ nil, nil ])
  end

  it "allows one home and one away entry per game, and sides only on games" do
    game, = game_between
    third = create(:team, league: league)
    extra = Contestant.new(contest: game, campaign: Campaign.create!(team: third, season: season), side: "home")
    expect(extra).not_to be_valid
    expect(Contestant.new(contest: game, campaign: extra.campaign, side: "visitor")).not_to be_valid
    cup = Contest.create!(name: "Cup", kind: "cup", context: league, season: season)
    expect(Contestant.new(contest: cup, campaign: home_campaign, side: "home")).not_to be_valid
  end

  it "fills missing venues and sides from bindings, then reports differences without overwriting" do
    game, home, away = game_between(code: "HCK-NHL-GAME_1")
    home.update!(side: nil)
    away.update!(side: nil)
    helsinki
    bindings = { games: [ { game: "HCK-NHL-GAME_1", stadium: helsinki.entity_code, home: home.entity_code, away: away.entity_code } ] }
    Dir.mktmpdir do |directory|
      path = File.join(directory, "bindings.json")
      File.write(path, JSON.generate(bindings))
      expect(Seeds::GameVenueImporter.new(source: path).call.transform_values(&:size)).to eq(updated: 1, unchanged: 0, conflicts: 0)
      expect([ game.reload.stadium, home.reload.side, away.reload.side ]).to eq([ helsinki, "home", "away" ])
      expect(Seeds::GameVenueImporter.new(source: path).call.transform_values(&:size)).to eq(updated: 0, unchanged: 1, conflicts: 0)

      game.update!(stadium: home_arena)
      report = Seeds::GameVenueImporter.new(source: path).call
      expect(report[:conflicts].sole[:differences]).to eq("stadium" => { existing: "STADIUM-HOME_ARENA", incoming: helsinki.entity_code })
      expect(game.reload.stadium).to eq(home_arena)
    end
  end
end
