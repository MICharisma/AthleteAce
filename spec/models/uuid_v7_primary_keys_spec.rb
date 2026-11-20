require "rails_helper"

RSpec.describe "UUIDv7 primary keys" do
  UUID_V7_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  it "assigns monotonic RFC 9562 UUIDv7 primary keys on ApplicationRecord models" do
    sports = 5.times.map { |i| create(:sport, name: "UUID Sport #{i}") }

    expect(sports.map(&:id)).to all(match(UUID_V7_FORMAT))
    expect(sports.map(&:id)).to eq(sports.map(&:id).sort)
    expect(sports.map(&:id).uniq.size).to eq(5)
  end

  it "preserves a caller-supplied UUIDv7 for idempotent offline sync" do
    preset_id = SecureRandom.uuid_v7
    sport = create(:sport, id: preset_id, name: "Preset UUID Sport")

    expect(sport.reload.id).to eq(preset_id)
  end

  it "assigns UUIDv7 primary keys on ActiveStorage::Blob records" do
    blob = ActiveStorage::Blob.create!(
      key: SecureRandom.hex(16),
      filename: "logo.png",
      byte_size: 4,
      checksum: Digest::MD5.base64digest("data"),
      service_name: "test"
    )

    expect(blob.id).to match(UUID_V7_FORMAT)
  end

  it "builds a valid SharedRatings::Dimension key with a UUID spectrum ID" do
    spectrum = create(:spectrum, name: "UUID Dimension Test")
    dimension = spectrum.rating_dimension

    expect(dimension.key).to eq("athleteace.spectrum.#{spectrum.id}")
  end

  it "retains rating_revisions when a rating or spectrum is destroyed" do
    ace = create(:ace)
    player = create(:player)
    spectrum = create(:spectrum, name: "Removable Spectrum")
    rating = Rating.create!(ace: ace, rated: player, spectrum: spectrum, value: 100)
    rating_id = rating.id
    spectrum_id = spectrum.id

    expect { spectrum.destroy! }.not_to raise_error

    revisions = RatingRevision.where(rating_id: rating_id).order(:created_at, :id)
    expect(revisions.pluck(:operation)).to eq(%w[set remove])
    expect(revisions.pluck(:spectrum_id).uniq).to eq([ spectrum_id ])
  end

  it "enforces the jersey_numbers_do_not_overlap exclusion constraint on UUID keys" do
    player = create(:player)
    team = player.team

    JerseyNumberAssignment.create!(player: player, team: team, number: "23",
      start_date: Date.new(2024, 1, 1), end_date: Date.new(2024, 12, 31))

    expect do
      JerseyNumberAssignment.new(player: player, team: team, number: "24",
        start_date: Date.new(2024, 6, 1), end_date: Date.new(2025, 1, 1)).save!(validate: false)
    end.to raise_error(ActiveRecord::StatementInvalid, /jersey_numbers_do_not_overlap/)
  end

  it "normalizes blank string filter params to nil in GameRoundSetup" do
    setup = GameRoundSetup.new(sport_id: "", league_id: "", team_id: "", player_id: "", player_group_id: "")

    expect(setup.sport_id).to be_nil
    expect(setup.league_id).to be_nil
    expect(setup.team_id).to be_nil
    expect(setup.player_id).to be_nil
    expect(setup.player_group_id).to be_nil
    expect(setup).to be_valid
  end

  it "retires float mode in UgcResetService" do
    expect { UgcResetService.new(mode: "float") }.to raise_error(ArgumentError, /Unknown reset mode/)
    expect { UgcResetService.new(mode: "clear") }.not_to raise_error
  end
end
