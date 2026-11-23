require "rails_helper"

RSpec.describe "Shot uploads" do
  let(:credential) { ShotUploadToken.issue!(label: "Portrait agent") }

  def upload(metadata: {}, key: "portrait-1", secret: credential.last, filename: "icon.png", type: "image/png")
    post api_v1_shots_path,
      params: { image: Rack::Test::UploadedFile.new(Rails.root.join("public", filename), type), metadata: metadata.to_json },
      headers: { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => key }
  end

  it "uploads bytes and tags a shot with weighted players resolved by code or alias" do
    first = create(:player, entity_code: "PLAYER-ONE")
    second = create(:player, entity_code: "PLAYER-TWO")
    EntityCode.create!(namespace: "MIC", catalog: "ALA", code: "PLAYER-ALIAS", canonical_code: second.entity_code, record: second)

    upload metadata: { tags: [" Portrait ", "sample"], captures: [
      { player_entity_code: "MIC-ALA-PLAYER-ONE", weight: 8 },
      { player_entity_code: "PLAYER-ALIAS", weight: 0 }
    ] }

    expect(response).to have_http_status(:created)
    shot = Shot.find(response.parsed_body.fetch("id"))
    expect(shot.shot_upload_token).to eq(credential.first)
    expect(shot.tags).to eq(%w[portrait sample])
    expect(shot.image.download).to eq(File.binread(Rails.root.join("public/icon.png")))
    expect(response.parsed_body.fetch("captures")).to match_array([
      a_hash_including("player_entity_code" => first.entity_code, "weight" => 8),
      a_hash_including("player_entity_code" => second.entity_code, "weight" => 0)
    ])
  end

  it "replays an unassigned upload and rejects a different payload under the same key" do
    upload
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch("id")

    expect { upload }.not_to change(Shot, :count)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("id" => id, "captures" => [])

    upload metadata: { tags: ["action"] }
    expect(response).to have_http_status(:conflict)
  end

  it "rejects invalid player codes before storing the file" do
    expect do
      upload metadata: { captures: [{ player_entity_code: "UNKNOWN-PLAYER" }] }
    end.not_to change(ActiveStorage::Blob, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(Shot.count).to eq(0)
  end

  it "rejects revoked credentials" do
    credential.first.update!(revoked_at: Time.current)

    expect { upload }.not_to change(Shot, :count)
    expect(response).to have_http_status(:unauthorized)
  end
end
