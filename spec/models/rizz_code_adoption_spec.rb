require "rails_helper"
require "tmpdir"

RSpec.describe "Adopting Rizz person codes" do
  def import_records(records)
    Dir.mktmpdir("people-seeds") do |directory|
      path = File.join(directory, "people.yaml")
      File.write(path, YAML.dump({ "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records }))
      Seeds::LibraryImporter.new.call([ path ])
    end
  end

  it "makes the Rizz code canonical and keeps the provisional code and earlier aliases resolving" do
    player = create :player, first_name: "Mark", last_name: "Scheifele", entity_code: "HKY-NHL-PLAYER-SCHEIFELE_MARK"
    person = player.person
    EntityCode.create!(namespace: "MIC", catalog: "ALA", code: "PERSON-SCHEIF", canonical_code: person.entity_code, record: person)
    expect(person.adopt_rizz_code!("MIC-RZZ-SCHE_MARK_7KM3")).to be(true)
    expect(person.reload).to have_attributes(entity_code: "MIC-RZZ-SCHE_MARK_7KM3", rizz_code?: true)
    expect(EntityCode.resolve(Person, "PERSON-HKY-NHL-PLAYER-SCHEIFELE_MARK")).to eq(person)
    expect(EntityCode.resolve(Person, "PERSON-SCHEIF")).to eq(person)
    expect(EntityCode.resolve(Person, "SCHE_MARK_7KM3", catalog: "RZZ")).to eq(person)
    expect(EntityCode.where(record: person).pluck(:canonical_code).uniq).to eq([ "MIC-RZZ-SCHE_MARK_7KM3" ])
    expect(person.adopt_rizz_code!("MIC-RZZ-SCHE_MARK_7KM3")).to be(false)
    expect { person.adopt_rizz_code!("PERSON-OTHER") }.to raise_error(ArgumentError)
  end

  it "lets a rebuilt athletic profile reclaim a person that adopted its Rizz code" do
    player = create :player, entity_code: "HKY-NHL-PLAYER-SCHEIFELE_MARK", first_name: "Mark", last_name: "Scheifele"
    person = player.person
    person.adopt_rizz_code!("MIC-RZZ-SCHE_MARK_7KM3")
    player.delete
    rebuilt = create :player, entity_code: "HKY-NHL-PLAYER-SCHEIFELE_MARK", first_name: "Mark", last_name: "Scheifele"
    expect(rebuilt.person).to eq(person)
    expect(Person.count).to eq(1)
  end

  it "replays seed records that use the provisional code without rebinding the Rizz code in AthleteAce's catalog" do
    records = [ { "type" => "Person", "code" => "PERSON-YAO_MING", "attributes" => { "name" => "Yao Ming", "short_name" => "Yao", "sort_name" => "Yao Ming" } } ]
    import_records(records)
    person = Person.sole
    person.adopt_rizz_code!("MIC-RZZ-YAO_MING_4QPX")
    replay = import_records(records)
    expect(replay[:created]).to be_empty
    expect(Person.sole).to have_attributes(id: person.id, entity_code: "MIC-RZZ-YAO_MING_4QPX")
    expect(EntityCode.where(catalog: "ALA").pluck(:code)).to eq([ "PERSON-YAO_MING" ])
    expect(EntityCode.find_by!(catalog: "RZZ").code).to eq("YAO_MING_4QPX")
  end
end
