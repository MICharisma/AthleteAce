require "rails_helper"
require "tmpdir"

RSpec.describe "Team naming and tenancy seed import" do
  let(:team) { create :team, entity_code: "FTB-NFL-TEAM-LV", territory: "Las Vegas", mascot: "Raiders" }
  let(:coliseum) { create :stadium, entity_code: "VENUE-US-OAKLAND_COLISEUM", name: "Oakland Coliseum" }

  def import(records)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "namings.json")
      File.write(path, JSON.generate(format: "micharisma-seeds/v1", namespace: "MIC", catalog: "ALA", records: records))
      Seeds::LibraryImporter.new.call([ path ])
    end
  end

  def records
    [
      { type: "Nickname", code: "NICKNAME-RAIDERS", attributes: { text: "Raiders" } },
      { type: "TeamNaming", code: "FTB-NFL-TEAM-LV-NAMING-1995", attributes: { territory: "Oakland", abbreviation: "OAK", start_date: "1995-07-01", end_date: "2020-01-21", source: { note: "Test source" } },
        references: { team: team.entity_code, nickname: "NICKNAME-RAIDERS" } },
      { type: "TeamNaming", code: "FTB-NFL-TEAM-LV-NAMING-2020", attributes: { territory: "Las Vegas", abbreviation: "LV", start_date: "2020-01-22" },
        references: { team: team.entity_code, nickname: "NICKNAME-RAIDERS" } },
      { type: "Tenancy", code: "FTB-NFL-TEAM-LV-TENANCY-OAKLAND_COLISEUM-1995", attributes: { start_date: "1995-09-03", end_date: "2019-12-15" },
        references: { team: team.entity_code, stadium: coliseum.entity_code } }
    ]
  end

  it "imports namings that share one nickname and a tenancy, then replays without changes" do
    expect(import(records)[:created].size).to eq(4)
    expect(team.name_on(Date.new(2010, 1, 1))).to eq("Oakland Raiders")
    expect(team.stadium_on(Date.new(2010, 1, 1))).to eq(coliseum)
    expect(Nickname.sole.teams).to eq([ team ])
    replay = import(records)
    expect(replay[:created]).to be_empty
    expect(replay[:unchanged].size).to eq(4)
  end

  it "adopts existing records by natural key and reports differences without rewriting them" do
    existing_nickname = Nickname.create! text: "raiders"
    existing = TeamNaming.create! team: team, nickname: existing_nickname, territory: "Oakland", start_date: "1995-06-01", end_date: "2020-01-21"
    report = import(records)
    expect(Nickname.sole).to eq(existing_nickname)
    expect(existing.reload.entity_code).to eq("FTB-NFL-TEAM-LV-NAMING-1995")
    expect(report[:conflicts].map { it[:code] }).to include("NICKNAME-RAIDERS", "FTB-NFL-TEAM-LV-NAMING-1995")
    expect(existing.start_date).to eq(Date.new(1995, 6, 1))
    expect(TeamNaming.count).to eq(2)
  end
end
