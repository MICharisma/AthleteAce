require "rails_helper"
require "tmpdir"

RSpec.describe "Formula One 2026 seeds" do
  # The F1 batch plus every record it references, the way the championship
  # history spec isolates its batch from the rest of the library.
  before(:context) do
    root = Rails.root.join("db/seeds/athlete_ace_data")
    registry = MICharismaSeeders::SequenceRegistry.read(root.join("yaml/entity_sequences.yaml"))
    all = MICharismaSeeders::Reader.new(registry: registry).read_many(Dir.glob(root.join("yaml/**/*.{yml,yaml,json}")).reject { |path| path.end_with?("entity_sequences.yaml") })
    index = Hash.new { |hash, key| hash[key] = [] }
    all.each { |row| ([ row.code ] + row.aliases).each { |code| index[code] << row } }
    pending = all.select { |row| row.location.include?("/yaml/f1_2026/") }
    selected = {}
    until pending.empty?
      row = pending.shift
      next if selected.key?(row.location)

      selected[row.location] = row
      (row.references.values + row.scope.values).each do |reference|
        pending.concat(index.fetch(reference.is_a?(Hash) ? reference.fetch("code") : reference))
      end
    end
    @records = selected.values.map do |row|
      { type: row.type, code: row.code, aliases: row.aliases, attributes: row.attributes,
        references: row.references, scope: row.scope, source: row.source }.compact
    end
  end

  def import
    Dir.mktmpdir do |directory|
      path = File.join(directory, "f1.json")
      File.write(path, JSON.generate(format: "micharisma-seeds/v1", namespace: "MIC", catalog: "ALA", records: @records))
      expect(Seeds::LibraryImporter.new.call([ path ])[:conflicts]).to be_empty
      replay = Seeds::LibraryImporter.new.call([ path ])
      expect([ replay[:created], replay[:conflicts] ]).to eq([ [], [] ])
    end
  end

  it "imports one motorsport league with its constructors, drivers, circuits and every session" do
    import
    league = League.find_by!(entity_code: "MOT-LEAGUE-F1")
    expect([ league.sport.name, league.jurisdiction.abbreviation ]).to eq([ "Motorsport", "FIA" ])
    season = Season.find_by!(entity_code: "MOT-F1-SEASON_2026")
    expect(season.campaigns.count).to eq(11)
    expect(Player.where(sport: league.sport).count).to eq(25)
    expect(Game.where(season: season).count).to eq(29)
    expect(Game.where(season: season).where(stadium_id: nil)).to be_empty
    championship = Contest.find_by!(entity_code: "MOT-F1-SEASON_2026-CHAMPIONSHIP")
    expect(championship.games.count).to eq(29)
    expect(championship.title_awards).to be_empty # The season was unfinished at capture.

    relocated = Game.find_by!(entity_code: "MOT-F1-SEASON_2026-ROUND_16-RACE")
    expect([ relocated.name, relocated.venue.name, relocated.venue.country.name ]).to eq([ "Bahrain Grand Prix in Malaysia", "Sepang International Circuit", "Malaysia" ])
    expect(Game.find_by!(entity_code: "MOT-F1-SEASON_2026-ROUND_21-RACE").appearances).to be_empty
  end

  it "keeps car numbers to observed runs, so a mid-season swap splits them" do
    import
    lawson = Player.find_by!(entity_code: "MOT-F1-PLAYER-LAWSON_LIAM")
    runs = lawson.jersey_number_assignments.order(:start_date).map { [ it.team.entity_code, it.start_date.iso8601, it.end_date.iso8601 ] }
    expect(runs).to eq([
      [ "MOT-F1-TEAM-RB", "2026-03-08", "2026-07-26" ],
      [ "MOT-F1-TEAM-RED_BULL", "2026-08-22", "2026-09-13" ],
      [ "MOT-F1-TEAM-RB", "2026-09-26", "2026-11-08" ]
    ])
    expect(lawson.campaigns.map { it.team.entity_code }).to contain_exactly("MOT-F1-TEAM-RB", "MOT-F1-TEAM-RED_BULL")
  end
end
