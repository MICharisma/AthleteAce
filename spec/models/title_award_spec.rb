require "rails_helper"
require "tmpdir"

RSpec.describe TitleAward do
  let(:league) { create(:league, name: "Formula One", entity_code: "MOT-LEAGUE-F1") }
  let(:season) { create(:season, league: league) }
  let(:team) { create(:team, league: league, territory: nil, mascot: "Red Bull Racing", entity_code: "MOT-F1-TEAM-RBR") }
  let(:campaign) { Campaign.create!(team: team, season: season, entity_code: "MOT-F1-SEASON-TEAM-RBR") }
  let(:championship) { Contest.create!(name: "World Drivers' Championship", kind: "championship", context: league, season: season, entity_code: "MOT-F1-WDC") }
  let(:entry) { Contestant.create!(contest: championship, campaign: campaign, entity_code: "MOT-F1-WDC-RBR") }
  let(:driver) { create(:player, first_name: "Max", last_name: "Verstappen", team: team, sport: league.sport, entity_code: "MOT-F1-PLAYER-VERSTAPPEN_MAX") }

  it "awards a title to a team entry, a person, or a person representing an entry" do
    constructors = championship.title_awards.create!(key: "constructors", name: "Constructors' title", winner: entry)
    drivers = championship.title_awards.create!(key: "drivers", name: "Drivers' title", player: driver, winner: entry)
    solo = championship.title_awards.create!(key: "pole_trophy", name: "Pole trophy", player: driver)

    expect(constructors.recipient).to eq(team)
    expect([ drivers.recipient, drivers.team ]).to eq([ driver, team ])
    expect(solo.recipient).to eq(driver)
    expect(championship.title_awards.person_titles).to contain_exactly(drivers, solo)
    expect(championship.title_awards.team_titles).to eq([ constructors ])
    expect(driver.title_awards).to contain_exactly(drivers, solo)
    expect { driver.destroy }.not_to change(Player, :count)
  end

  it "requires a recipient in the model and the database" do
    expect(championship.title_awards.new(key: "empty", name: "Empty")).not_to be_valid
    expect { TitleAward.insert_all!([ { contest_id: championship.id, key: "empty", name: "Empty", created_at: Time.current, updated_at: Time.current } ]) }
      .to raise_error(ActiveRecord::StatementInvalid, /title_awards_have_a_recipient/)
  end

  it "rejects a person from another sport and an entry from another competition" do
    golfer = create(:player)
    expect(championship.title_awards.new(key: "drivers", name: "Drivers' title", player: golfer)).not_to be_valid
    other = Contest.create!(name: "Sprint series", kind: "championship", context: league, season: season)
    stray = Contestant.create!(contest: other, campaign: campaign)
    expect(championship.title_awards.new(key: "drivers", name: "Drivers' title", player: driver, winner: stray)).not_to be_valid
  end

  it "imports and replays a person title from seeds" do
    entry
    driver
    league.sport.update!(entity_code: "SPORT-MOT")
    document = { format: "micharisma-seeds/v1", namespace: "MIC", catalog: "ALA", source: { note: "Test source" }, records: [
      { type: "TitleAward", code: "MOT-F1-WDC-DRIVERS", attributes: { key: "drivers", name: "Drivers' title" },
        references: { contest: championship.entity_code, player: driver.entity_code, winner: entry.entity_code } },
      { type: "TitleAward", code: "MOT-F1-WDC-POLE", attributes: { key: "pole_trophy", name: "Pole trophy" },
        references: { contest: championship.entity_code, player: driver.entity_code } }
    ] }
    Dir.mktmpdir do |directory|
      path = File.join(directory, "titles.json")
      File.write(path, JSON.generate(document))
      expect(Seeds::LibraryImporter.new.call([ path ])[:created].size).to eq(2)
      replay = Seeds::LibraryImporter.new.call([ path ])
      expect(replay[:created]).to be_empty
      expect(replay[:conflicts]).to be_empty
      expect(championship.title_awards.find_by!(key: "drivers").recipient).to eq(driver)
      expect(championship.title_awards.find_by!(key: "pole_trophy").winner).to be_nil
    end
  end
end
