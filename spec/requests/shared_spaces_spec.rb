require "rails_helper"

RSpec.describe "Shared space", type: :request do
  let(:ace) { create(:ace) }

  around { |example| with_rizz_env { example.run } }

  it "redirects signed-out visitors to sign in" do
    get shared_space_path
    expect(response).to redirect_to(new_ace_session_path)
  end

  context "when signed in without a linked Rizz account" do
    before { sign_in ace }

    it "shows the connect Rizz prompt" do
      get shared_space_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Connect your Rizz account")
      expect(response.body).to include("#{RizzSpeaker::ISSUER}/places")
    end
  end

  context "when signed in with an active Rizz binding" do
    let!(:binding) do
      AceRizzBinding.create!(
        ace: ace,
        rizz_sub: "rizz-sub-42",
        operation_id: SecureRandom.uuid,
        status: "active",
        connected_at: Time.current,
        rizz_session_epoch: 1
      )
    end

    let(:us) { create(:country, name: "United States", abbreviation: "US", entity_code: "COUNTRY-US") }
    let(:ma) { create(:state, name: "Massachusetts", abbreviation: "MA", country: us, entity_code: "STATE-US-MA") }
    let(:boston_city) { create(:city, name: "Boston", state: ma, entity_code: "CITY-US-MA-BOSTON") }
    let!(:celtics) { create(:team, territory: "Boston", mascot: "Celtics", stadium: create(:stadium, name: "TD Garden", city: boston_city)) }

    before { sign_in ace }

    it "renders era-segmented teams with normal engagement controls" do
      places_result = RizzSignIn::PlacesClient::Result.new(
        status: :ok,
        places: [
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
          }
        ],
        trips: [],
        current_zone: nil,
        error: nil
      )
      allow(RizzSignIn::PlacesClient).to receive(:fetch).with(rizz_sub: "rizz-sub-42").and_return(places_result)

      get shared_space_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Boston")
      expect(response.body).to include("1984")
      expect(response.body).to include("1988")
      expect(response.body).to include("Boston Celtics")
      expect(response.body).to include("engagements-radial")
      expect(response.body).to include("Save")
      expect(response.body).to include("Favorite")
      expect(response.body).to include("Follow")
      expect(response.body).to include("Hide")
    end

    it "renders a disconnected state when Rizz returns 410 Gone" do
      disconnected = RizzSignIn::PlacesClient::Result.new(status: :disconnected, places: [], trips: [], current_zone: nil, error: "410")
      allow(RizzSignIn::PlacesClient).to receive(:fetch).with(rizz_sub: "rizz-sub-42").and_return(disconnected)

      get shared_space_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rizz connection paused")
    end

    it "renders an empty state when no places are shared with AthleteAce" do
      empty = RizzSignIn::PlacesClient::Result.new(status: :ok, places: [], trips: [], current_zone: nil, error: nil)
      allow(RizzSignIn::PlacesClient).to receive(:fetch).with(rizz_sub: "rizz-sub-42").and_return(empty)

      get shared_space_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No places shared with AthleteAce yet")
    end

    it "renders an unavailable state when Rizz cannot be reached" do
      unavailable = RizzSignIn::PlacesClient::Result.new(status: :unavailable, places: [], trips: [], current_zone: nil, error: "Net::ReadTimeout")
      allow(RizzSignIn::PlacesClient).to receive(:fetch).with(rizz_sub: "rizz-sub-42").and_return(unavailable)

      get shared_space_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Couldn’t reach Rizz right now")
    end
  end
end
