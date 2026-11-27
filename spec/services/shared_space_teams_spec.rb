require "rails_helper"

RSpec.describe SharedSpaceTeams do
  let(:sport) { create(:sport, name: "Basketball") }
  let(:league) { create(:league, name: "NBA", sport: sport) }
  let(:nfl) { create(:league, name: "NFL", sport: create(:sport, name: "Football")) }

  let(:us) { create(:country, name: "United States", abbreviation: "US", entity_code: "COUNTRY-US") }
  let(:ma) { create(:state, name: "Massachusetts", abbreviation: "MA", country: us, entity_code: "STATE-US-MA") }
  let(:ny) { create(:state, name: "New York", abbreviation: "NY", country: us, entity_code: "STATE-US-NY") }
  let(:nj) { create(:state, name: "New Jersey", abbreviation: "NJ", country: us, entity_code: "STATE-US-NJ") }
  let(:ct) { create(:state, name: "Connecticut", abbreviation: "CT", country: us, entity_code: "STATE-US-CT") }
  let(:ca) { create(:state, name: "California", abbreviation: "CA", country: us, entity_code: "STATE-US-CA") }
  let(:or_state) { create(:state, name: "Oregon", abbreviation: "OR", country: us, entity_code: "STATE-US-OR") }

  let(:boston_city) { create(:city, name: "Boston", state: ma, entity_code: "CITY-US-MA-BOSTON") }
  let(:foxborough_city) { create(:city, name: "Foxborough", state: ma, entity_code: "CITY-US-MA-FOXBOROUGH") }
  let(:nyc_city) { create(:city, name: "New York", state: ny, entity_code: "CITY-US-NY-NEW_YORK") }
  let(:east_rutherford_city) { create(:city, name: "East Rutherford", state: nj, entity_code: "CITY-US-NJ-EAST_RUTHERFORD") }
  let(:inglewood_city) { create(:city, name: "Inglewood", state: ca, entity_code: "CITY-US-CA-INGLEWOOD") }
  let(:la_city) { create(:city, name: "Los Angeles", state: ca, entity_code: "CITY-US-CA-LOS_ANGELES") }
  let(:portland_or_city) { create(:city, name: "Portland", state: or_state, entity_code: "CITY-US-OR-PORTLAND") }

  let!(:celtics) { create(:team, territory: "Boston", mascot: "Celtics", league: league, stadium: create(:stadium, name: "TD Garden", city: boston_city)) }
  let!(:patriots) { create(:team, territory: "New England", mascot: "Patriots", league: nfl, stadium: create(:stadium, name: "Gillette Stadium", city: foxborough_city)) }
  let!(:nets) { create(:team, territory: "Brooklyn", mascot: "Nets", league: league, stadium: create(:stadium, name: "Barclays Center", city: nyc_city)) }
  let!(:knicks) { create(:team, territory: "New York", mascot: "Knicks", league: league, stadium: create(:stadium, name: "Madison Square Garden", city: nyc_city)) }
  let!(:giants) { create(:team, territory: "New York", mascot: "Giants", league: nfl, stadium: create(:stadium, name: "MetLife Stadium", city: east_rutherford_city)) }
  let!(:lakers) { create(:team, territory: "Los Angeles", mascot: "Lakers", league: league, stadium: create(:stadium, name: "Crypto.com Arena", city: la_city)) }
  let!(:clippers) { create(:team, territory: "Los Angeles", mascot: "Clippers", league: league, stadium: create(:stadium, name: "Intuit Dome", city: inglewood_city)) }
  let!(:blazers) { create(:team, territory: "Portland", mascot: "Trail Blazers", league: league, stadium: create(:stadium, name: "Moda Center", city: portland_or_city)) }

  let(:places) do
    [
      {
        "id" => "p-brooklyn",
        "label" => "Brooklyn",
        "place_code" => "MIC-RZZ-LOC-US-NY-BROOKLYN",
        "ancestor_codes" => [ "MIC-RZZ-DIV-US-NY", "MIC-RZZ-CTRY-US" ],
        "city_name" => "Brooklyn, New York, United States",
        "kind" => "residence",
        "is_home" => true,
        "started_on" => "2004-01-01",
        "ended_on" => nil,
        "date_precision" => "year"
      },
      {
        "id" => "p-boston",
        "label" => "Boston",
        "place_code" => "MIC-RZZ-LOC-US-MA-BOSTON",
        "ancestor_codes" => [ "MIC-RZZ-DIV-US-MA", "MIC-RZZ-CTRY-US" ],
        "city_name" => "Boston, Massachusetts, United States",
        "kind" => "hometown",
        "is_home" => false,
        "started_on" => "1984-01-01",
        "ended_on" => "1988-01-01",
        "date_precision" => "year"
      },
      {
        "id" => "p-albany",
        "label" => "Albany",
        "place_code" => "MIC-RZZ-LOC-US-NY-ALBANY",
        "ancestor_codes" => [ "MIC-RZZ-DIV-US-NY", "MIC-RZZ-CTRY-US" ],
        "city_name" => "Albany, New York, United States",
        "kind" => "residence",
        "is_home" => false,
        "started_on" => "1988-01-01",
        "ended_on" => "2002-01-01",
        "date_precision" => "year"
      },
      {
        "id" => "p-newhaven",
        "label" => "New Haven",
        "place_code" => "MIC-RZZ-LOC-US-CT-NEW_HAVEN",
        "ancestor_codes" => [ "MIC-RZZ-DIV-US-CT", "MIC-RZZ-CTRY-US" ],
        "city_name" => "New Haven, Connecticut, United States",
        "kind" => "residence",
        "is_home" => false,
        "started_on" => "2002-01-01",
        "ended_on" => "2006-01-01",
        "date_precision" => "year"
      }
    ]
  end

  let(:trips) do
    [
      {
        "id" => "t-la",
        "label" => "Los Angeles",
        "status" => "completed",
        "starts_on" => "2013-06-01",
        "ends_on" => nil,
        "date_precision" => "month",
        "place" => {
          "label" => "Los Angeles",
          "place_code" => "MIC-RZZ-LOC-US-CA-LOS_ANGELES",
          "ancestor_codes" => [ "MIC-RZZ-DIV-US-CA", "MIC-RZZ-CTRY-US" ],
          "city_name" => "Los Angeles, California, United States"
        }
      },
      {
        "id" => "t-portland-me",
        "label" => "Portland",
        "status" => "completed",
        "starts_on" => "2010-01-01",
        "ends_on" => nil,
        "date_precision" => "year",
        "place" => {
          "label" => "Portland",
          "place_code" => "MIC-RZZ-LOC-US-ME-PORTLAND",
          "ancestor_codes" => [ "MIC-RZZ-DIV-US-ME", "MIC-RZZ-CTRY-US" ],
          "city_name" => "Portland, Maine, United States"
        }
      }
    ]
  end

  it "orders home eras chronologically and matches city, NYC borough, suburban territory, and state teams" do
    result = described_class.call(
      places: places,
      trips: trips,
      current_zone: { "place_id" => "p-brooklyn", "label" => "Brooklyn" }
    )

    expect(result.home_eras.map(&:label)).to eq([ "Boston", "Albany", "New Haven", "Brooklyn" ])

    boston = result.home_eras[0]
    expect(boston.span_label).to eq("1984 – 1988")
    expect(boston.direct_teams).to eq([ celtics ])
    expect(boston.regional_teams).to eq([ patriots ])
    expect(boston.state_name).to eq("Massachusetts")

    albany = result.home_eras[1]
    expect(albany.direct_teams).to be_empty
    expect(albany.regional_teams).to contain_exactly(nets, knicks)
    expect(albany.state_name).to eq("New York")

    new_haven = result.home_eras[2]
    expect(new_haven.direct_teams).to be_empty
    expect(new_haven.regional_teams).to be_empty
    expect(new_haven.state_name).to eq("Connecticut")

    brooklyn = result.home_eras[3]
    expect(brooklyn.span_label).to eq("2004 – Now")
    expect(brooklyn.active_now).to be(true)
    expect(brooklyn.direct_teams).to contain_exactly(nets, knicks, giants)
    expect(brooklyn.regional_teams).to be_empty
  end

  it "orders trips chronologically, matches suburban territory teams, and avoids homonymous city collisions" do
    result = described_class.call(places: [], trips: trips)

    expect(result.trip_eras.map(&:label)).to eq([ "Portland", "Los Angeles" ])

    portland_me = result.trip_eras[0]
    expect(portland_me.span_label).to eq("2010")
    expect(portland_me.direct_teams).to be_empty
    expect(portland_me.regional_teams).to be_empty

    la = result.trip_eras[1]
    expect(la.span_label).to eq("Jun 2013")
    expect(la.direct_teams).to contain_exactly(lakers, clippers)
  end
end
