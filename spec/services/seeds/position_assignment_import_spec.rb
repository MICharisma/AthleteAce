require "rails_helper"
require "tmpdir"

RSpec.describe "Position assignment seed import" do
  # Polymorphic references are typed by their catalog binding.
  def bind(*records)
    records.each { |record| EntityCode.create!(namespace: "MIC", catalog: "ALA", code: record.entity_code, canonical_code: record.entity_code, record: record) }
  end

  it "imports positions and observed assignments, then replays without creating or conflicting" do
    league = create(:league, entity_code: "BSB-LEAGUE-MLB")
    sport = league.sport
    sport.update!(entity_code: "SPORT-BSB")
    team = create(:team, league: league, entity_code: "BSB-MLB-TEAM-SEA")
    season = create(:season, league: league, entity_code: "BSB-MLB-SEASON_2026")
    campaign = Campaign.create!(team: team, season: season, entity_code: "BSB-MLB-SEASON_2026-TEAM-SEA")
    player = create(:player, team: team, sport: sport, entity_code: "BSB-MLB-PLAYER-EXAMPLE")
    roster = Roster.create!(campaign: campaign, kind: "observed", effective_on: Date.new(2026, 4, 1), entity_code: "SEA-ROSTER-2026_04_01")
    entry = RosterEntry.create!(roster: roster, player: player, entity_code: "SEA-ROSTER-2026_04_01-EXAMPLE")
    game = Contest.create!(name: "Opener", kind: "game", context: league, season: season, entity_code: "BSB-MLB-GAME-OPENER")
    played = Appearance.create!(player: player, contestant: Contestant.create!(contest: game, campaign: campaign), entity_code: "BSB-MLB-GAME-OPENER-EXAMPLE")
    legacy = create(:position, sport: sport, name: "Outfield", abbreviation: "OF")
    bind(entry, played)

    positions = [
      { type: "Position", code: "BSB-POSITION-OF", attributes: { name: "Outfield", abbreviation: "OF" }, references: { sport: "SPORT-BSB" } },
      { type: "Position", code: "BSB-POSITION-LF", attributes: { name: "Left field", abbreviation: "LF" }, references: { sport: "SPORT-BSB", parent: "BSB-POSITION-OF" } },
      { type: "Position", code: "BSB-POSITION-1B", attributes: { name: "First base", abbreviation: "1B" }, references: { sport: "SPORT-BSB" } }
    ]
    assignments = [
      { type: "PositionAssignment", code: "SEA-ROSTER-2026_04_01-EXAMPLE-POSITION-OF", attributes: { primary: true },
        references: { subject: entry.entity_code, position: "BSB-POSITION-OF" } },
      { type: "PositionAssignment", code: "BSB-MLB-GAME-OPENER-EXAMPLE-POSITION_1", attributes: { sequence: 1 },
        references: { subject: played.entity_code, position: "BSB-POSITION-LF" } },
      { type: "PositionAssignment", code: "BSB-MLB-GAME-OPENER-EXAMPLE-POSITION_2", attributes: { sequence: 2, statistics: { innings: 3 } },
        references: { subject: played.entity_code, position: "BSB-POSITION-1B" } }
    ]
    document = { format: "micharisma-seeds/v1", namespace: "MIC", catalog: "ALA", source: { note: "Test source" }, records: positions + assignments }

    Dir.mktmpdir do |directory|
      path = File.join(directory, "positions.json")
      File.write(path, JSON.generate(document))
      first = Seeds::LibraryImporter.new.call([ path ])
      expect(first[:created].size).to eq(5) # the legacy Outfield is adopted, not created
      expect(first[:conflicts]).to be_empty
      expect(legacy.reload.entity_code).to eq("BSB-POSITION-OF")

      replay = Seeds::LibraryImporter.new.call([ path ])
      expect(replay[:created]).to be_empty
      expect(replay[:conflicts]).to be_empty

      expect(played.position_assignments.in_order.map { it.position.abbreviation }).to eq(%w[LF 1B])
      expect(played.position_assignments.find_by(sequence: 2).statistics).to eq("innings" => 3)
      expect(Position.find_by(entity_code: "BSB-POSITION-LF").parent).to eq(legacy)
      expect(player.primary_position).to eq(legacy)

      document[:records][-1][:references][:position] = "BSB-POSITION-LF"
      File.write(path, JSON.generate(document))
      changed = Seeds::LibraryImporter.new.call([ path ])
      expect(changed[:conflicts].map { it[:code] }).to eq([ "BSB-MLB-GAME-OPENER-EXAMPLE-POSITION_2" ])
      expect(played.position_assignments.find_by(sequence: 2).position.abbreviation).to eq("1B")
    end
  end

  it "rejects assignments to subjects that cannot hold positions" do
    team = create(:team, entity_code: "BKT-NBA-TEAM-NYK")
    team.league.sport.update!(entity_code: "SPORT-BKT")
    bind(team)
    document = { format: "micharisma-seeds/v1", namespace: "MIC", catalog: "ALA", records: [
      { type: "Position", code: "BKT-POSITION-G", attributes: { name: "Guard" }, references: { sport: "SPORT-BKT" } },
      { type: "PositionAssignment", code: "BKT-NYK-POSITION-G", references: { subject: team.entity_code, position: "BKT-POSITION-G" } }
    ] }
    Dir.mktmpdir do |directory|
      path = File.join(directory, "positions.json")
      File.write(path, JSON.generate(document))
      expect { Seeds::LibraryImporter.new.call([ path ]) }.to raise_error(Seeds::LibraryImporter::Error, /invalid for PositionAssignment.subject/)
      expect(Position.count).to eq(0)
    end
  end
end
