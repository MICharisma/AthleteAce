require "rails_helper"

RSpec.describe RizzSignIn::HttpClient do
  def stub_response(response)
    allow(Net::HTTP).to receive(:start).and_return(response)
  end

  def http_response(klass, code, body)
    klass.new("1.1", code.to_s, "").tap { |response| allow(response).to receive(:body).and_return(body) }
  end

  it "returns a parsed JSON object" do
    stub_response http_response(Net::HTTPOK, 200, { "a" => 1 }.to_json)
    expect(described_class.get_json("https://rizz.test/x")).to eq("a" => 1)
  end

  it "treats 4xx on get_json as unavailable and rejects 4xx (except 429) on post_form as InvalidToken" do
    [ 400, 401, 403, 404, 429, 499 ].each do |code|
      stub_response http_response(Net::HTTPClientError, code, "{}")
      expect { described_class.get_json("https://rizz.test/x") }.to raise_error(RizzSignIn::Unavailable)
    end

    [ 400, 401 ].each do |code|
      stub_response http_response(Net::HTTPClientError, code, "{}")
      expect { described_class.post_form("https://rizz.test/x", { code: "x" }, basic_auth: %w[id secret]) }.to raise_error(RizzSignIn::InvalidToken)
    end

    stub_response http_response(Net::HTTPClientError, 429, "{}")
    expect { described_class.post_form("https://rizz.test/x", { code: "x" }, basic_auth: %w[id secret]) }.to raise_error(RizzSignIn::Unavailable)
  end

  it "treats 5xx and redirects as unavailable" do
    stub_response http_response(Net::HTTPServerError, 503, "{}")
    expect { described_class.get_json("https://rizz.test/x") }.to raise_error(RizzSignIn::Unavailable)
    stub_response http_response(Net::HTTPFound, 302, "")
    expect { described_class.get_json("https://rizz.test/x") }.to raise_error(RizzSignIn::Unavailable)
  end

  it "treats a JSON body that is not an object as unavailable" do
    [ "[]", "\"text\"", "42", "null" ].each do |body|
      stub_response http_response(Net::HTTPOK, 200, body)
      expect { described_class.get_json("https://rizz.test/x") }.to raise_error(RizzSignIn::Unavailable)
    end
  end

  it "treats malformed JSON and oversized bodies as unavailable" do
    stub_response http_response(Net::HTTPOK, 200, "{not json")
    expect { described_class.get_json("https://rizz.test/x") }.to raise_error(RizzSignIn::Unavailable)
    stub_response http_response(Net::HTTPOK, 200, "x" * (described_class::MAX_BYTES + 1))
    expect { described_class.get_json("https://rizz.test/x") }.to raise_error(RizzSignIn::Unavailable)
  end

  it "treats protocol-level HTTP errors as unavailable" do
    [ Net::HTTPBadResponse, Net::ProtocolError, Net::ReadTimeout, Errno::ECONNREFUSED ].each do |error|
      allow(Net::HTTP).to receive(:start).and_raise(error)
      expect { described_class.get_json("https://rizz.test/x") }.to raise_error(RizzSignIn::Unavailable)
    end
  end
end
