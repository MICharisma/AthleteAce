require "set"

# Segments AthleteAce teams by the eras (homes and trips) a speaker has shared
# from Rizz. Teams are matched geographically to each era's city/metro (direct)
# and state/division (regional fallback), ready to layer historical tenancy
# dates on top as historical venue timelines are populated.
class SharedSpaceTeams
  RIZZ_LOC_PREFIX = "MIC-RZZ-LOC-".freeze
  RIZZ_DIV_PREFIX = "MIC-RZZ-DIV-".freeze
  RIZZ_CTRY_PREFIX = "MIC-RZZ-CTRY-".freeze

  NYC_BOROUGH_CODES = %w[
    MIC-RZZ-LOC-US-NY-BROOKLYN
    MIC-RZZ-LOC-US-NY-MANHATTAN
    MIC-RZZ-LOC-US-NY-QUEENS
    MIC-RZZ-LOC-US-NY-BRONX
    MIC-RZZ-LOC-US-NY-STATEN_ISLAND
  ].to_set.freeze

  NYC_CITY_CODES = %w[MIC-RZZ-LOC-US-NY-NEW_YORK CITY-US-NY-NEW_YORK].freeze

  Era = Data.define(
    :id, :entry_type, :label, :city_name, :place_code, :kind, :is_home,
    :started_on, :ended_on, :date_precision, :status,
    :direct_teams, :regional_teams, :state_name, :time_zone, :active_now
  ) do
    def dom_anchor
      "era-#{entry_type}-#{id.to_s.parameterize.presence || label.to_s.parameterize}"
    end

    def home?
      entry_type == :home
    end

    def trip?
      entry_type == :trip
    end

    def total_teams_count
      direct_teams.size + regional_teams.size
    end

    def any_teams?
      total_teams_count.positive?
    end

    def start_label
      format_date(started_on, date_precision)
    end

    def end_label
      if ended_on
        format_date(ended_on, date_precision)
      elsif home? && (started_on || is_home)
        "Now"
      end
    end

    def rail_lines
      if home?
        return [ start_label, end_label ].compact if started_on || ended_on
        return [ "Now" ] if is_home

        [ "Era" ]
      else
        return [ "Trip" ] if started_on.nil? && ended_on.nil?

        s = start_label
        e = format_date(ended_on, date_precision)
        e && e != s ? [ s, e ] : [ s || e ]
      end
    end

    def span_label
      lines = rail_lines
      lines.size == 2 ? "#{lines.first} – #{lines.last}" : lines.first
    end

    private

    def format_date(date, precision)
      return unless date

      case precision.to_s
      when "day" then date.strftime("%b %-d, %Y")
      when "month" then date.strftime("%b %Y")
      else date.strftime("%Y")
      end
    end
  end

  Result = Data.define(:home_eras, :trip_eras, :current_zone, :all_teams, :direct_team_count, :regional_team_count) do
    def empty?
      home_eras.empty? && trip_eras.empty?
    end

    def era_count
      home_eras.size + trip_eras.size
    end
  end

  TeamIndex = Data.define(:team, :city_codes, :state_codes, :country_code, :territory_key, :city_name_key, :state_name)

  def self.call(places:, trips: [], current_zone: nil, teams: nil)
    new(places: places, trips: trips, current_zone: current_zone, teams: teams).call
  end

  def initialize(places:, trips: [], current_zone: nil, teams: nil)
    @places = Array(places)
    @trips = Array(trips)
    @current_zone = current_zone
    @teams = teams
  end

  def call
    indexed_teams = build_team_index
    state_names_by_code = build_state_name_lookup(indexed_teams)

    home_eras = sort_home_places(@places).map do |place|
      build_era(
        entry_type: :home,
        id: place["id"],
        label: place["label"].presence || short_city_name(place["city_name"]) || "Place",
        place_data: place,
        kind: place["kind"],
        is_home: ActiveModel::Type::Boolean.new.cast(place["is_home"]),
        started_on: parse_date(place["started_on"]),
        ended_on: parse_date(place["ended_on"]),
        date_precision: place["date_precision"].presence || "year",
        status: nil,
        indexed_teams: indexed_teams,
        state_names_by_code: state_names_by_code
      )
    end

    trip_eras = sort_trips(@trips).map do |trip|
      place = trip["place"].is_a?(Hash) ? trip["place"] : {}
      build_era(
        entry_type: :trip,
        id: trip["id"],
        label: trip["label"].presence || place["label"].presence || short_city_name(place["city_name"]) || "Trip",
        place_data: place,
        kind: "trip",
        is_home: false,
        started_on: parse_date(trip["starts_on"]),
        ended_on: parse_date(trip["ends_on"]),
        date_precision: trip["date_precision"].presence || "year",
        status: trip["status"],
        indexed_teams: indexed_teams,
        state_names_by_code: state_names_by_code
      )
    end

    all_eras = home_eras + trip_eras
    direct_ids = all_eras.flat_map { |era| era.direct_teams.map(&:id) }.uniq
    all_teams = all_eras.flat_map { |era| era.direct_teams + era.regional_teams }.uniq(&:id)
    regional_only_count = (all_teams.map(&:id) - direct_ids).size

    Result.new(
      home_eras: home_eras,
      trip_eras: trip_eras,
      current_zone: @current_zone,
      all_teams: all_teams,
      direct_team_count: direct_ids.size,
      regional_team_count: regional_only_count
    )
  end

  private

  def load_teams
    return @teams.to_a if @teams

    Team.includes(
      :division,
      stadium: { city: { state: :country } },
      primary_logo: { asset_representations: { file_attachment: :blob } },
      current_logos: { asset_representations: { file_attachment: :blob } },
      league: [
        :sport,
        primary_logo: { asset_representations: { file_attachment: :blob } },
        current_logos: { asset_representations: { file_attachment: :blob } }
      ]
    ).to_a
  end

  def build_team_index
    teams = load_teams
    aliases_by_record = load_place_aliases(teams)

    teams.map do |team|
      city = team.stadium&.city
      state = city&.state
      country = state&.country

      city_codes = Set.new
      city_codes << city.entity_code if city&.entity_code.present?
      city_codes.merge(aliases_by_record[[ "City", city.id ]]) if city

      state_codes = Set.new
      state_codes << state.entity_code if state&.entity_code.present?
      state_codes.merge(aliases_by_record[[ "State", state.id ]]) if state

      TeamIndex.new(
        team: team,
        city_codes: city_codes,
        state_codes: state_codes,
        country_code: country&.entity_code,
        territory_key: team.territory.to_s.strip.downcase,
        city_name_key: city&.name.to_s.strip.downcase,
        state_name: state&.name
      )
    end
  end

  def load_place_aliases(teams)
    city_ids = teams.filter_map { |team| team.stadium&.city_id }.uniq
    state_ids = teams.filter_map { |team| team.stadium&.city&.state_id }.uniq
    return Hash.new { |h, k| h[k] = [] } if city_ids.empty? && state_ids.empty?

    records = EntityCode.where(record_type: "City", record_id: city_ids)
      .or(EntityCode.where(record_type: "State", record_id: state_ids))
      .pluck(:record_type, :record_id, :code, :canonical_code)

    records.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(type, record_id, code, canonical), map|
      map[[ type, record_id ]] << code if code.present?
      map[[ type, record_id ]] << canonical if canonical.present?
    end
  end

  def build_state_name_lookup(indexed_teams)
    lookup = {}
    indexed_teams.each do |entry|
      next if entry.state_name.blank?

      entry.state_codes.each { |code| lookup[code] ||= entry.state_name }
    end
    lookup
  end

  def sort_home_places(places)
    far_future = Date.new(9999, 12, 31)
    places.sort_by do |place|
      started = parse_date(place["started_on"])
      ended = parse_date(place["ended_on"])
      is_home = ActiveModel::Type::Boolean.new.cast(place["is_home"])
      [
        started ? 0 : (is_home ? 1 : 2),
        started || far_future,
        ended || far_future,
        place["label"].to_s.downcase
      ]
    end
  end

  def sort_trips(trips)
    far_future = Date.new(9999, 12, 31)
    trips.sort_by do |trip|
      starts = parse_date(trip["starts_on"])
      ends = parse_date(trip["ends_on"])
      [
        starts ? 0 : 1,
        starts || far_future,
        ends || far_future,
        trip["label"].to_s.downcase
      ]
    end
  end

  def build_era(entry_type:, id:, label:, place_data:, kind:, is_home:, started_on:, ended_on:, date_precision:, status:, indexed_teams:, state_names_by_code:)
    matchers = place_matchers(place_data, fallback_label: label)
    direct = []
    regional = []

    indexed_teams.each do |entry|
      if direct_match?(entry, matchers)
        direct << entry.team
      elsif regional_match?(entry, matchers)
        regional << entry.team
      end
    end

    direct.sort_by! { |team| [ team.league&.name.to_s.downcase, team.name.downcase ] }
    regional.sort_by! { |team| [ team.league&.name.to_s.downcase, team.name.downcase ] }

    state_name = resolve_state_name(matchers[:state_codes], place_data["city_name"], state_names_by_code)
    current_id = @current_zone&.dig("place_id")
    active_now = entry_type == :home && (
      (current_id.present? && current_id.to_s == id.to_s) ||
      (current_id.blank? && is_home && ended_on.nil?)
    )

    Era.new(
      id: id,
      entry_type: entry_type,
      label: label,
      city_name: place_data["city_name"],
      place_code: place_data["place_code"],
      kind: kind,
      is_home: is_home,
      started_on: started_on,
      ended_on: ended_on,
      date_precision: date_precision,
      status: status,
      direct_teams: direct,
      regional_teams: regional,
      state_name: state_name,
      time_zone: place_data["time_zone"],
      active_now: active_now
    )
  end

  def place_matchers(place_data, fallback_label:)
    place_code = place_data["place_code"].to_s.strip
    ancestors = Array(place_data["ancestor_codes"]).map { |code| code.to_s.strip }.reject(&:blank?)

    city_codes = Set.new
    state_codes = Set.new
    country_codes = Set.new
    territory_names = Set.new

    if place_code.present?
      city_codes << place_code
      if place_code.start_with?(RIZZ_LOC_PREFIX)
        suffix = place_code.delete_prefix(RIZZ_LOC_PREFIX)
        city_codes << "CITY-#{suffix}"
        if (match = suffix.match(/\A([A-Z]{2})-([A-Z0-9]+)-/))
          state_codes << "#{RIZZ_DIV_PREFIX}#{match[1]}-#{match[2]}"
          state_codes << "STATE-#{match[1]}-#{match[2]}"
          country_codes << "#{RIZZ_CTRY_PREFIX}#{match[1]}"
          country_codes << "COUNTRY-#{match[1]}"
        end
      elsif place_code.start_with?(RIZZ_DIV_PREFIX)
        suffix = place_code.delete_prefix(RIZZ_DIV_PREFIX)
        state_codes << place_code
        state_codes << "STATE-#{suffix}"
      end

      if NYC_BOROUGH_CODES.include?(place_code)
        city_codes.merge(NYC_CITY_CODES)
        territory_names << "new york"
      end
    end

    ancestors.each do |code|
      if code.start_with?(RIZZ_LOC_PREFIX)
        city_codes << code
        city_codes << "CITY-#{code.delete_prefix(RIZZ_LOC_PREFIX)}"
      elsif code.start_with?(RIZZ_DIV_PREFIX)
        state_codes << code
        state_codes << "STATE-#{code.delete_prefix(RIZZ_DIV_PREFIX)}"
      elsif code.start_with?(RIZZ_CTRY_PREFIX)
        country_codes << code
        country_codes << "COUNTRY-#{code.delete_prefix(RIZZ_CTRY_PREFIX)}"
      end
    end

    city_short = short_city_name(place_data["city_name"]) || fallback_label
    territory_names << city_short.downcase if city_short.present?

    {
      city_codes: city_codes,
      state_codes: state_codes,
      country_codes: country_codes,
      territory_names: territory_names
    }
  end

  def direct_match?(entry, matchers)
    return true if matchers[:city_codes].any? && (entry.city_codes & matchers[:city_codes]).any?
    return false unless matchers[:territory_names].include?(entry.territory_key)

    if matchers[:country_codes].any? && entry.country_code.present?
      return false unless matchers[:country_codes].include?(entry.country_code)
    end

    # Guard against homonymous cities in different states (e.g. Portland, OR vs Portland, ME)
    # while still allowing suburban/cross-state metro teams (e.g. NY Giants in East Rutherford, NJ).
    if matchers[:state_codes].any? && entry.state_codes.any? && (entry.state_codes & matchers[:state_codes]).empty?
      return false if entry.city_name_key == entry.territory_key
    end

    true
  end

  def regional_match?(entry, matchers)
    matchers[:state_codes].any? && (entry.state_codes & matchers[:state_codes]).any?
  end

  def resolve_state_name(state_codes, city_name, state_names_by_code)
    state_codes.each do |code|
      return state_names_by_code[code] if state_names_by_code[code].present?
    end

    parts = city_name.to_s.split(",").map(&:strip).reject(&:blank?)
    parts[1] if parts.size >= 3
  end

  def short_city_name(city_name)
    city_name.to_s.split(",").first&.strip.presence
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error, ArgumentError
    nil
  end
end
