require "rails_helper"

RSpec.describe "Team visual assets" do
  let(:team) { create(:team) }
  let(:source) { { url: "https://www.nhl.com/blues/team/brand" } }

  it "stores league marks and validates each entity's primary logo ownership" do
    league = team.league
    league_logo = Logo.create! owner: league, name: "League mark"
    team_logo = Logo.create! owner: team, name: "Team mark"
    league.update! primary_logo: league_logo
    team.update! primary_logo: team_logo
    expect(league.logos).to contain_exactly league_logo
    team.primary_logo = league_logo
    expect(team).not_to be_valid
    expect(team.errors[:primary_logo]).to be_present
  end

  it "keeps a Figure's primary portrait attached to that Figure" do
    figure = create :figure
    portrait = AssetRepresentation.create! subject: figure, file_format: "png", view: "nba_headshot",
      canonical_path: "media/headshot.png", content_type: "image/png", byte_size: 100, sha256: "a" * 64
    figure.update! primary_portrait: portrait
    other = create :figure
    other.primary_portrait = portrait
    expect(other).not_to be_valid
    expect(other.errors[:primary_portrait]).to be_present
  end

  it "prefers the PNG rendition while retaining the original SVG" do
    logo = Logo.create! owner: team, name: "League mark"
    images = %w[svg png].map do |format|
      asset = AssetRepresentation.create! subject: logo, file_format: format, view: "default", canonical_path: "media/mark.#{format}",
        entity_code: "MARK-FILE-#{format.upcase}", content_type: format == "svg" ? "image/svg+xml" : "image/png", byte_size: 1, sha256: "a" * 64
      asset.file.attach io: StringIO.new("x"), filename: "mark.#{format}", content_type: asset.content_type, identify: false
      asset
    end
    expect(logo.image.blob).to eq images.last.file.blob
    expect(logo.asset_representations.count).to eq 2
  ensure
    images&.each { |asset| asset.file.purge }
  end

  it "allows concurrent logos and distinguishes unknown dates from ongoing use" do
    primary = Logo.create!(owner: team, name: "Blue Note", role: "primary", start_date: "2025-06-20", ongoing: true, source: source)
    alternate = Logo.create!(owner: team, name: "Fleur", role: "alternate", start_date: "2025-06-20", ongoing: true, source: source)
    expect(team.logos).to contain_exactly(primary, alternate)
    expect(Logo.new(owner: team, name: "Archive mark", source: source)).to be_valid
    expect(Logo.new(owner: team, name: "Invalid period", start_date: "2026-01-01", end_date: "2025-01-01")).not_to be_valid
    primary.end_date = "2026-10-26"
    expect(primary).not_to be_valid
  end

  it "reuses a uniform across seasons and prevents assignment to another team" do
    uniform = Uniform.create!(team: team, name: "Home blue", source: source)
    first = Campaign.create!(team: team, season: create(:season, league: team.league))
    second = Campaign.create!(team: team, season: create(:season, league: team.league))
    uniform.campaigns << first << second
    expect(uniform.campaigns).to contain_exactly(first, second)
    other_team = create(:team)
    other_campaign = Campaign.create!(team: other_team, season: create(:season, league: other_team.league))
    expect(UniformCampaign.new(uniform: uniform, campaign: other_campaign)).not_to be_valid
    expect(uniform.uniform_pieces.create!(name: "sweater").name).to eq("sweater")
    expect(uniform.uniform_pieces.create!(name: "pants").name).to eq("pants")
  end

  it "stores distinct formats and views with one canonical file for each" do
    uniform = Uniform.create!(team: team, name: "Association")
    piece = uniform.uniform_pieces.create!(name: "jersey")
    attributes = { subject: piece, view: "front", canonical_path: "media/pilot/jersey.svg", file_format: "svg", content_type: "image/svg+xml", byte_size: 100, sha256: "a" * 64 }
    AssetRepresentation.create!(attributes)
    expect(AssetRepresentation.new(attributes)).not_to be_valid
    expect(AssetRepresentation.new(attributes.merge(file_format: "png", canonical_path: "media/pilot/jersey.png", content_type: "image/png"))).to be_valid
    expect(AssetRepresentation.new(attributes.merge(view: "back"))).to be_valid
    expect(AssetRepresentation.new(attributes.merge(canonical_path: "media/../../outside.svg"))).not_to be_valid
  end
end
