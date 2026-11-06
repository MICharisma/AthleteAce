require "rails_helper"
require "tmpdir"

RSpec.describe "People and staff seed imports" do
  def import_records(records)
    Dir.mktmpdir("people-seeds") do |directory|
      path = File.join(directory, "people.yaml")
      File.write(path, YAML.dump({ "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records }))
      Seeds::LibraryImporter.new.call([ path ])
    end
  end

  def definition(type, code, attributes, references = {})
    { "type" => type, "code" => code, "attributes" => attributes, "references" => references }
  end

  it "adopts an athlete's identity by profile reference and replays appointments and aliases" do
    player = create :player, first_name: "Jordan", last_name: "Reyes", entity_code: "PLAYER-REYES_JORDAN"
    person = player.person
    records = [
      definition("StaffTenure", "APPOINTMENT-REYES-BROADCAST-2025",
        { "role" => "broadcaster", "title" => "Color commentator", "start_date" => "2025", "ongoing" => true,
          "source" => { "title" => "Broadcast announcement", "url" => "https://example.com/announcements/reyes" } },
        { "person" => "PERSON-REYES_JORDAN", "organization" => "ORGANIZATION-HARBOR_MEDIA" }),
      definition("Person", "PERSON-REYES_JORDAN", { "name" => "Jordan Reyes" }, { "player" => player.entity_code }),
      definition("Organization", "ORGANIZATION-HARBOR_MEDIA", { "name" => "Harbor Sports Network" })
    ]
    report = import_records(records)
    expect(report[:conflicts]).to be_empty
    expect(Person.count).to eq(1)
    expect(StaffTenure.sole.person).to eq(person)
    expect(StaffTenure.sole.start_date).to eq("2025")
    expect(Seeds::LibraryImporter.new.resolve_code("Person", "PERSON-REYES_JORDAN")).to eq(person)
    original_ids = [ person.id, StaffTenure.sole.id ]
    replay = import_records(records.reverse)
    expect(replay[:created]).to be_empty
    expect(replay[:conflicts]).to be_empty
    expect([ Person.sole.id, StaffTenure.sole.id ]).to eq(original_ids)
    expect(EntityCode.find_by!(code: "PERSON-REYES_JORDAN").record).to eq(person)
  end

  it "keeps same-name staff separate and reports conflicting evidence without overwriting it" do
    records = [
      definition("Person", "PERSON-CALDERON_MARIA-COACH", { "name" => "María Calderón" }),
      definition("Person", "PERSON-CALDERON_MARIA-ANALYST", { "name" => "María Calderón" }),
      definition("Organization", "ORGANIZATION-HARBOR", { "name" => "Harbor Athletics" }),
      definition("StaffTenure", "APPOINTMENT-CALDERON-COACH-2024",
        { "role" => "coach", "title" => "Development coach", "start_date" => "2024-09",
          "source" => { "title" => "Staff directory" } },
        { "person" => "PERSON-CALDERON_MARIA-COACH", "organization" => "ORGANIZATION-HARBOR" })
    ]
    import_records(records)
    expect(Person.count).to eq(2)
    expect(Player.count).to eq(0)
    records.last["attributes"]["title"] = "Head coach"
    report = import_records(records)
    expect(report[:conflicts].sole[:differences]["title"]).to eq(existing: "Development coach", incoming: "Head coach")
    expect(StaffTenure.sole.title).to eq("Development coach")
  end

  it "imports names on Person records and links players to them by reference" do
    sport = create :sport, entity_code: "SPORT-BKT"
    football = create :sport, entity_code: "SPORT-FTB"
    baseball = create :sport, entity_code: "SPORT-BSB"
    records = [
      definition("Player", "BKT-NBA-PLAYER-YAO_MING", { "debut_year" => 2002 }, { "sport" => "SPORT-BKT", "person" => "PERSON-YAO_MING" }),
      definition("Person", "PERSON-YAO_MING", {
        "name" => "Yao Ming", "short_name" => "Yao", "sort_name" => "Yao Ming", "name_segments" => [ "Yao", "Ming" ],
        "alternate_names" => [ "姚明" ], "nicknames" => [ "The Great Wall" ] }),
      definition("Person", "PERSON-SANDERS_DEION", { "first_name" => "Deion", "last_name" => "Sanders", "nicknames" => [ "Prime Time" ] }),
      definition("Player", "FTB-NFL-PLAYER-SANDERS_DEION", {}, { "sport" => "SPORT-FTB", "person" => "PERSON-SANDERS_DEION" }),
      definition("Player", "BSB-MLB-PLAYER-SANDERS_DEION", {}, { "sport" => "SPORT-BSB", "person" => "PERSON-SANDERS_DEION" })
    ]
    report = import_records(records)
    expect(report[:conflicts]).to be_empty

    yao = Player.find_by!(entity_code: "BKT-NBA-PLAYER-YAO_MING")
    expect(yao).to have_attributes(sport: sport, name: "Yao Ming", short_name: "Yao", name_segments: [ "Yao", "Ming" ])
    expect(yao.person.entity_code).to eq("PERSON-YAO_MING")
    expect(Player.matching_name("姚明")).to eq([ yao ])
    deion = Person.find_by!(entity_code: "PERSON-SANDERS_DEION")
    expect(deion.players.map(&:sport)).to contain_exactly(football, baseball)
    expect(deion).to have_attributes(name: "Deion Sanders", sort_name: "Sanders, Deion", name_segments: [ "Deion", "Sanders" ])
    expect(Person.count).to eq(2)

    replay = import_records(records)
    expect(replay[:created]).to be_empty
    expect(replay[:conflicts]).to be_empty
  end

  it "matches roster code parts against short and sort names, not only first and last" do
    elly = create :player, first_name: "Elly", last_name: "De La Cruz"
    yao = create :player, person: create(:person, name: "Yao Ming", short_name: "Yao", sort_name: "Yao Ming", name_segments: [ "Yao", "Ming" ])
    josé = create :player, first_name: "José", last_name: "Ramírez"
    expect(Player.named_in_code("DE_LA_CRUZ")).to eq([ elly ])
    expect(Player.named_in_code("DE_LA_CRUZ_ELLY")).to eq([ elly ])
    expect(Player.named_in_code("YAO_MING")).to eq([ yao ])
    expect(Player.named_in_code("RAMIREZ_JOSE")).to eq([ josé ])
  end
end
