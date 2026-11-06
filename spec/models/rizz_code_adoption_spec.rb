require "rails_helper"
require "tmpdir"

RSpec.describe "Adopting Rizz figure codes" do
  def import_records(records)
    Dir.mktmpdir("figures-seeds") do |directory|
      path = File.join(directory, "figures.yaml")
      File.write(path, YAML.dump({ "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records }))
      Seeds::LibraryImporter.new.call([ path ])
    end
  end

  it "makes the Rizz code canonical and keeps the provisional code and earlier aliases resolving" do
    player = create :player, first_name: "Mark", last_name: "Scheifele", entity_code: "HKY-NHL-PLAYER-SCHEIFELE_MARK"
    figure = player.figure
    EntityCode.create!(namespace: "MIC", catalog: "ALA", code: "FIGURE-SCHEIF", canonical_code: figure.entity_code, record: figure)
    expect(figure.adopt_rizz_code!("MIC-RZZ-SCHE_MARK_7KM3")).to be(true)
    expect(figure.reload).to have_attributes(entity_code: "MIC-RZZ-SCHE_MARK_7KM3", rizz_code?: true)
    expect(EntityCode.resolve(Figure, "FIGURE-HKY-NHL-PLAYER-SCHEIFELE_MARK")).to eq(figure)
    expect(EntityCode.resolve(Figure, "FIGURE-SCHEIF")).to eq(figure)
    expect(EntityCode.resolve(Figure, "SCHE_MARK_7KM3", catalog: "RZZ")).to eq(figure)
    expect(EntityCode.where(record: figure).pluck(:canonical_code).uniq).to eq([ "MIC-RZZ-SCHE_MARK_7KM3" ])
    expect(figure.adopt_rizz_code!("MIC-RZZ-SCHE_MARK_7KM3")).to be(false)
    expect { figure.adopt_rizz_code!("FIGURE-OTHER") }.to raise_error(ArgumentError)
  end

  it "lets a rebuilt athletic profile reclaim a figure that adopted its Rizz code" do
    player = create :player, entity_code: "HKY-NHL-PLAYER-SCHEIFELE_MARK", first_name: "Mark", last_name: "Scheifele"
    figure = player.figure
    figure.adopt_rizz_code!("MIC-RZZ-SCHE_MARK_7KM3")
    player.delete
    rebuilt = create :player, entity_code: "HKY-NHL-PLAYER-SCHEIFELE_MARK", first_name: "Mark", last_name: "Scheifele"
    expect(rebuilt.figure).to eq(figure)
    expect(Figure.count).to eq(1)
  end

  it "replays seed records that use the provisional code without rebinding the Rizz code in AthleteAce's catalog" do
    records = [ { "type" => "Figure", "code" => "FIGURE-YAO_MING", "attributes" => { "name" => "Yao Ming", "short_name" => "Yao", "sort_name" => "Yao Ming" } } ]
    import_records(records)
    figure = Figure.sole
    figure.adopt_rizz_code!("MIC-RZZ-YAO_MING_4QPX")
    replay = import_records(records)
    expect(replay[:created]).to be_empty
    expect(Figure.sole).to have_attributes(id: figure.id, entity_code: "MIC-RZZ-YAO_MING_4QPX")
    expect(EntityCode.where(catalog: "ALA").pluck(:code)).to eq([ "FIGURE-YAO_MING" ])
    expect(EntityCode.find_by!(catalog: "RZZ").code).to eq("YAO_MING_4QPX")
  end
end
