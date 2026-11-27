require "rails_helper"

RSpec.describe RizzSignIn::PlacesClient do
  around { |example| with_rizz_env { example.run } }

  def fake_http_response(code:, body:)
    klass = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s)
    response = klass.new("1.1", code.to_s, "")
    allow(response).to receive(:body).and_return(body)
    response
  end

  it "returns :disabled when Rizz is not configured" do
    with_rizz_env("RIZZ_OIDC_ISSUER" => nil, "RIZZ_OIDC_CLIENT_ID" => nil, "RIZZ_OIDC_CLIENT_SECRET" => nil) do
      result = described_class.fetch(rizz_sub: "sub-123")

      expect(result.status).to eq(:disabled)
      expect(result.places).to eq([])
      expect(result.trips).to eq([])
    end
  end

  it "fetches shared places and trips with HTTP Basic auth" do
    payload = {
      "sub" => "sub-123",
      "sector_id" => "athleteace",
      "current_zone" => { "place_id" => "p1", "label" => "Brooklyn" },
      "places" => [ { "id" => "p1", "label" => "Brooklyn", "place_code" => "MIC-RZZ-LOC-US-NY-BROOKLYN" } ],
      "trips" => [ { "id" => "t1", "label" => "Austin", "starts_on" => "2011-01-01" } ]
    }

    captured_request = nil
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |req|
      captured_request = req
      fake_http_response(code: 200, body: payload.to_json)
    end
    allow(Net::HTTP).to receive(:start).with("rizz.test", 443, hash_including(use_ssl: true)).and_yield(http)

    result = described_class.fetch(rizz_sub: "sub-123")

    expect(result).to be_ok
    expect(result.places.size).to eq(1)
    expect(result.trips.size).to eq(1)
    expect(result.current_zone["label"]).to eq("Brooklyn")
    expect(captured_request.path).to eq("/api/v1/speakers/sub-123/places")
    expect(captured_request["Accept"]).to eq("application/json")
    expect(captured_request["Authorization"]).to start_with("Basic ")
  end

  it "returns :disconnected on 410 Gone" do
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request).and_return(fake_http_response(code: 410, body: '{"error":"site_disconnected"}'))
    allow(Net::HTTP).to receive(:start).and_yield(http)

    result = described_class.fetch(rizz_sub: "sub-123")

    expect(result).to be_disconnected
  end

  it "returns :unavailable on network errors" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)

    result = described_class.fetch(rizz_sub: "sub-123")

    expect(result).to be_unavailable
    expect(result.error).to eq("Net::ReadTimeout")
  end

  it "builds the manage places URL from the issuer" do
    expect(described_class.manage_url).to eq("#{RizzSpeaker::ISSUER}/places")
  end
end
