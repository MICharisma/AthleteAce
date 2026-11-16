require "rails_helper"
require "net/http"

RSpec.describe AssetRepresentation do
  let(:bytes) { '<svg xmlns="http://www.w3.org/2000/svg"><circle r="10"/></svg>' }
  let(:github) { { "repository" => "MICharisma/athlete_ace_media", "commit" => "a" * 40, "path" => "logos/harbor.svg" } }
  let(:asset) do
    described_class.create! subject: Logo.create!(owner: create(:team), name: "Harbor Athletics mark"),
      entity_code: "HARBOR-LOGO-SVG", canonical_path: "media/logos/harbor.svg", file_format: "svg", view: "default",
      content_type: "image/svg+xml", sha256: Digest::SHA256.hexdigest(bytes), byte_size: bytes.bytesize,
      source: { "github" => github }
  end
  let(:http) { instance_double Net::HTTP }
  let(:response) { Net::HTTPOK.new "1.1", "200", "OK" }

  before do
    allow(Net::HTTP).to receive(:start).with("raw.githubusercontent.com", 443,
      use_ssl: true, open_timeout: 10, read_timeout: 30).and_yield http
    allow(http).to receive(:request_get).with("/MICharisma/athlete_ace_media/#{'a' * 40}/logos/harbor.svg").and_yield response
    allow(response).to receive(:read_body).and_yield bytes
  end

  after { asset.file.purge if asset.file.attached? }

  it "downloads the pinned file into application storage and serves the same bytes" do
    expect(asset.ingest_file!).to eq :imported
    expect(asset.reload.file.download).to eq bytes
    expect(asset.file.content_type).to eq "image/svg+xml"
    expect { asset.verify_file! }.not_to raise_error
  end

  it "verifies the stored file on replay without another GitHub request or blob" do
    expect(http).to receive(:request_get).once.and_yield response
    asset.ingest_file!
    expect { expect(asset.ingest_file!).to eq :unchanged }.not_to change ActiveStorage::Blob, :count
  end

  it "rejects a checksum mismatch before storing a file" do
    asset.update! sha256: "b" * 64
    expect { asset.ingest_file! }.to raise_error described_class::IntegrityError, /checksum differs/
    expect(asset.reload.file).not_to be_attached
    expect(ActiveStorage::Blob.count).to eq 0
  end

  it "rejects a short download" do
    allow(response).to receive(:read_body).and_yield bytes[0...-1]
    expect { asset.ingest_file! }.to raise_error described_class::IntegrityError, /size differs/
    expect(asset.reload.file).not_to be_attached
  end

  it "stops an oversized download before attaching it" do
    allow(response).to receive(:read_body).and_yield(bytes).and_yield("extra")
    expect { asset.ingest_file! }.to raise_error described_class::IntegrityError, /exceeds recorded size/
    expect(asset.reload.file).not_to be_attached
  end

  it "reports missing GitHub files without storing the error response" do
    allow(http).to receive(:request_get).and_yield Net::HTTPNotFound.new("1.1", "404", "Not Found")
    expect { asset.ingest_file! }.to raise_error described_class::IntegrityError, /HTTP 404/
    expect(asset.reload.file).not_to be_attached
  end

  it "does not follow a redirect to another download host" do
    allow(http).to receive(:request_get).and_yield Net::HTTPFound.new("1.1", "302", "Found")
    expect { asset.ingest_file! }.to raise_error described_class::IntegrityError, /HTTP 302/
    expect(asset.reload.file).not_to be_attached
  end

  it "rejects branch names and unsafe repository paths" do
    asset.source["github"] = github.merge "commit" => "main"
    expect(asset).not_to be_valid
    ["../logo.svg", "/logo.svg", "logos//logo.svg", "logos/..", "logos\\logo.svg"].each do |path|
      asset.source["github"] = github.merge "path" => path
      expect(asset).not_to be_valid
    end
  end

  it "escapes filename characters without changing the fixed download host" do
    asset.source["github"] = github.merge "path" => "logos/Harbor & Blue.svg"
    expect(asset.github_url).to eq "https://raw.githubusercontent.com/MICharisma/athlete_ace_media/#{'a' * 40}/logos/Harbor%20%26%20Blue.svg"
  end

  it "reports absent source metadata and absent stored files" do
    asset.update! source: {}
    expect { asset.ingest_file! }.to raise_error described_class::IntegrityError, /Missing pinned GitHub source/
    expect { asset.verify_file! }.to raise_error described_class::IntegrityError, /Missing stored file/
  end

  it "verifies existing bytes against the current seed checksum on replay" do
    asset.ingest_file!
    asset.update! sha256: "b" * 64
    expect { asset.ingest_file! }.to raise_error described_class::IntegrityError, /checksum differs/
  end
end
