# Finds AthleteAce's countries, states and cities in Rizz's place catalog and
# adopts their MIC-RZZ codes (MIC-RZZ-CTRY-US, MIC-RZZ-DIV-GB-ENG,
# MIC-RZZ-LOC-US-NY-NEW_YORK), keeping each record's own COUNTRY-, STATE- or
# CITY- code as an alias. Seeding never calls Rizz; this runs as its own step
# (rake rizz:sync_places).
#
# Countries resolve by ISO 3166-1 code and states by ISO 3166-2 code (country
# and state abbreviation: US-CA, GB-ENG). A city resolves only when exactly one
# Rizz locality inside its state has its name; an ambiguous or missing city
# keeps its own code and is reported, never guessed. A Rizz place that another
# local record already holds is reported as a conflict.
#
# Each record takes the code at its own tier. Where Rizz holds one place for
# the same land at two tiers, the lower tier is an alias: AthleteAce's state DC
# takes MIC-RZZ-DIV-US-DC and its city Washington MIC-RZZ-LOC-US-DC-WASHINGTON,
# both naming one Rizz place.
#
# Needs the rizz-client gem, RIZZ_ENDPOINT and RIZZ_API_TOKEN.
class RizzPlaceSync
  Outcome = Data.define(:record, :state, :code, :detail)

  def self.client
    require "rizz-client"
    Rizz::Client.new(endpoint: ENV.fetch("RIZZ_ENDPOINT"), token: ENV.fetch("RIZZ_API_TOKEN"))
  end

  def initialize(client: self.class.client)
    @client = client
  end

  # Countries first, so each state and city can use its container's code.
  def call
    Country.order(:id).map { |country| sync(country) { resolve("iso3166-1:alpha2", country.abbreviation, "CTRY") } } +
      State.includes(:country).order(:id).map { |state| sync(state) { resolve("iso3166-2", iso3166_2(state), "DIV") } } +
      City.includes(state: :country).order(:id).map { |city| sync(city) { reconcile(city) } }
  end

  private

  attr_reader :client

  # A Rizz place code never changes, so an adopted record needs no request.
  def sync(record)
    return Outcome.new(record, "unchanged", record.entity_code, nil) if record.rizz_code?

    code, detail = yield
    return Outcome.new(record, "missing", nil, detail) unless code
    return Outcome.new(record, "unchanged", code, nil) if record.entity_code == code

    holder = holder_of(code, record)
    return Outcome.new(record, "conflict", code, "#{holder.class.name} #{holder.id} holds #{code}") if holder

    record.adopt_rizz_code!(code)
    Outcome.new(record, "adopted", code, nil)
  rescue Rizz::Unavailable, Rizz::Error => error
    Outcome.new(record, "failed", nil, "#{error.class}: #{error.message}".truncate(255))
  end

  # Another local record, of any model, that already holds this Rizz code.
  def holder_of(code, record)
    record.class.where(entity_code: code).where.not(id: record.id).first ||
      EntityCode.find_by(namespace: AdoptsRizzCode::RIZZ_NAMESPACE, catalog: AdoptsRizzCode::RIZZ_CATALOG, code: code.delete_prefix(AdoptsRizzCode::RIZZ_PREFIX))
        &.then { |binding| binding.record unless binding.record_type == record.class.polymorphic_name && binding.record_id == record.id }
  end

  def resolve(namespace, external_id, tier)
    binding = client.resolve_place(namespace: namespace, external_id: external_id)
    code_at(client.entity(binding.fetch("entity_id")), tier)
  rescue Rizz::Error => error
    raise unless error.status == 404
    [nil, "no Rizz place for #{namespace} #{external_id}"]
  end

  def reconcile(city)
    container = "DIV-#{iso3166_2(city.state)}"
    result = client.reconcile_place(query: city.name, tiers: ["LOC"], within: container)
    if result.fetch("decision") == "matched"
      candidate = result.fetch("candidates").first
      return candidate["qualified_matched_code"] || candidate.fetch("qualified_code")
    end

    candidates = result.fetch("candidates").map { |candidate| candidate.fetch("code") }
    [nil, candidates.empty? ? "no Rizz locality named #{city.name} in #{container}" : "ambiguous: #{candidates.join(', ')}"]
  end

  # The place's own code at that tier, or its alias there for the same land.
  def code_at(place, tier)
    return place.fetch("qualified_code") if place["place_tier"].nil? || place["place_tier"] == tier
    alias_code = place.fetch("alias_codes", []).find { |code| code.start_with?("#{tier}-") }
    alias_code ? "#{AdoptsRizzCode::RIZZ_PREFIX}#{alias_code}" : place.fetch("qualified_code")
  end

  def iso3166_2(state)
    "#{state.country.abbreviation}-#{state.abbreviation}"
  end
end
