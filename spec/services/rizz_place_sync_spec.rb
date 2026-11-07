require "rails_helper"

RSpec.describe RizzPlaceSync do
  let(:client) { double("Rizz client") }
  let(:service) { described_class.new(client: client) }
  let!(:country) { create :country, name: "United States", abbreviation: "US", entity_code: "COUNTRY-US" }
  let!(:state) { create :state, name: "New York", abbreviation: "NY", country: country, entity_code: "STATE-US-NY" }
  let!(:city) { create :city, name: "New York", state: state, entity_code: "CITY-US-NY-NEW_YORK" }

  before do
    stub_const("Rizz::Error", Class.new(StandardError) { attr_accessor :status })
    stub_const("Rizz::Unavailable", Class.new(StandardError))
    places = { "iso3166-1:alpha2:US" => "ctry", "iso3166-2:US-NY" => "div" }
    allow(client).to receive(:resolve_place) do |namespace:, external_id:|
      id = places["#{namespace}:#{external_id}"]
      raise Rizz::Error.new.tap { |error| error.status = 404 } unless id
      { "entity_id" => id }
    end
    allow(client).to receive(:entity).with("ctry").and_return("qualified_code" => "MIC-RZZ-CTRY-US")
    allow(client).to receive(:entity).with("div").and_return("qualified_code" => "MIC-RZZ-DIV-US-NY")
  end

  def matched(code)
    { "decision" => "matched", "candidates" => [{ "code" => code, "qualified_code" => "MIC-RZZ-#{code}" }] }
  end

  it "adopts Rizz codes by ISO code and by one locality match, keeping AthleteAce's codes as aliases" do
    expect(client).to receive(:reconcile_place).with(query: "New York", tiers: ["LOC"], within: "DIV-US-NY").and_return(matched("LOC-US-NY-NEW_YORK"))

    outcomes = service.call

    expect(outcomes.map { |outcome| [outcome.record, outcome.state] }).to eq([[country, "adopted"], [state, "adopted"], [city, "adopted"]])
    expect([country, state, city].map { |record| record.reload.entity_code }).to eq(%w[MIC-RZZ-CTRY-US MIC-RZZ-DIV-US-NY MIC-RZZ-LOC-US-NY-NEW_YORK])
    expect(EntityCode.resolve(City, "CITY-US-NY-NEW_YORK")).to eq(city)
    expect(EntityCode.resolve(State, "DIV-US-NY", catalog: "RZZ")).to eq(state)
    expect(service.call.map(&:state)).to eq(%w[unchanged unchanged unchanged])
  end

  it "reports ambiguous, missing and already-held places without adopting them" do
    other = create :city, name: "Burbank", state: state, entity_code: "CITY-US-NY-BURBANK"
    held = create :city, name: "Brooklyn", state: state, entity_code: "MIC-RZZ-LOC-US-NY-BROOKLYN"
    twin = create :city, name: "Brooklyn Heights", state: state, entity_code: "CITY-US-NY-BROOKLYN_HEIGHTS"
    create :state, name: "Nowhere", abbreviation: "ZZ", country: country, entity_code: "STATE-US-ZZ"
    allow(client).to receive(:reconcile_place).with(query: "New York", tiers: ["LOC"], within: "DIV-US-NY")
      .and_return("decision" => "review_required", "candidates" => [{ "code" => "LOC-US-NY-NEW_YORK" }, { "code" => "LOC-US-NY-NEW_YORK_2" }])
    allow(client).to receive(:reconcile_place).with(query: "Burbank", tiers: ["LOC"], within: "DIV-US-NY").and_return("decision" => "unresolved", "candidates" => [])
    allow(client).to receive(:reconcile_place).with(query: "Brooklyn", tiers: ["LOC"], within: "DIV-US-NY").and_return(matched("LOC-US-NY-BROOKLYN"))
    allow(client).to receive(:reconcile_place).with(query: "Brooklyn Heights", tiers: ["LOC"], within: "DIV-US-NY").and_return(matched("LOC-US-NY-BROOKLYN"))

    outcomes = service.call.index_by(&:record)

    expect(outcomes.fetch(city)).to have_attributes(state: "missing", detail: "ambiguous: LOC-US-NY-NEW_YORK, LOC-US-NY-NEW_YORK_2")
    expect(outcomes.fetch(other)).to have_attributes(state: "missing", detail: "no Rizz locality named Burbank in DIV-US-NY")
    expect(outcomes.fetch(held).state).to eq("unchanged")
    expect(outcomes.fetch(twin)).to have_attributes(state: "conflict", detail: "City #{held.id} holds MIC-RZZ-LOC-US-NY-BROOKLYN")
    expect(outcomes.values.find { |outcome| outcome.record.is_a?(State) && outcome.record.abbreviation == "ZZ" }.detail).to eq("no Rizz place for iso3166-2 US-ZZ")
    expect([city, other, twin].map { |record| record.reload.entity_code }).to eq(%w[CITY-US-NY-NEW_YORK CITY-US-NY-BURBANK CITY-US-NY-BROOKLYN_HEIGHTS])
  end

  it "gives a city on its state's land the locality alias, leaving the division code to the state" do
    dc = create :state, name: "District of Columbia", abbreviation: "DC", country: country, entity_code: "STATE-US-DC"
    washington = create :city, name: "Washington", state: dc, entity_code: "CITY-US-DC-WASHINGTON"
    allow(client).to receive(:resolve_place).with(namespace: "iso3166-2", external_id: "US-DC").and_return("entity_id" => "dc")
    allow(client).to receive(:entity).with("dc").and_return("qualified_code" => "MIC-RZZ-DIV-US-DC", "place_tier" => "DIV", "alias_codes" => ["LOC-US-DC-WASHINGTON"])
    allow(client).to receive(:reconcile_place).with(query: "New York", tiers: ["LOC"], within: "DIV-US-NY").and_return(matched("LOC-US-NY-NEW_YORK"))
    allow(client).to receive(:reconcile_place).with(query: "Washington", tiers: ["LOC"], within: "DIV-US-DC")
      .and_return("decision" => "matched", "candidates" => [{ "code" => "DIV-US-DC", "qualified_code" => "MIC-RZZ-DIV-US-DC", "qualified_matched_code" => "MIC-RZZ-LOC-US-DC-WASHINGTON" }])

    service.call

    expect(dc.reload.entity_code).to eq("MIC-RZZ-DIV-US-DC")
    expect(washington.reload.entity_code).to eq("MIC-RZZ-LOC-US-DC-WASHINGTON")
  end

  it "replays location seed records by their old codes without rebinding the Rizz code in AthleteAce's catalog" do
    records = [{ "type" => "Country", "code" => "COUNTRY-CA", "attributes" => { "name" => "Canada", "abbreviation" => "CA" } }]
    import = lambda do
      Dir.mktmpdir("places-seeds") do |directory|
        path = File.join(directory, "geography.yaml")
        File.write(path, YAML.dump({ "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records }))
        Seeds::LibraryImporter.new.call([path])
      end
    end
    import.call
    canada = Country.find_by!(abbreviation: "CA")
    canada.adopt_rizz_code!("MIC-RZZ-CTRY-CA")
    replay = import.call
    expect(replay[:created]).to be_empty
    expect(canada.reload.entity_code).to eq("MIC-RZZ-CTRY-CA")
    expect(EntityCode.where(record: canada, catalog: "ALA").pluck(:code)).to eq(["COUNTRY-CA"])
  end
end
