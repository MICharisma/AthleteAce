require "rails_helper"

RSpec.describe "Admin shots" do
  it "uploads a shot with no players and filters by its tags" do
    sign_in create(:ace, :admin)

    post admin_shots_path, params: { shot: {
      image: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"),
      tags: " Warm-up, SAMPLE, warm-up "
    } }

    shot = Shot.sole
    expect(response).to redirect_to(edit_admin_shot_path(shot))
    expect(shot.tags).to eq(%w[warm-up sample])
    expect(shot.players).to be_empty

    get admin_shots_path, params: { tag: "warm-up", unassigned: "1" }
    expect(response.parsed_body.at_css("a[href='#{edit_admin_shot_path(shot)}'] img")["src"]).to eq(shot.url)
  end

  it "tags multiple players with independent selection weights" do
    sign_in create(:ace, :admin)
    shot = Shot.create!(external_url: "/icon.png")
    first, second = create_list(:player, 2)

    get edit_admin_shot_path(shot), params: { q: first.last_name }
    expect(response.parsed_body.at_css("select[name='capture[player_id]'] option[value='#{first.id}']")).to be_present

    post admin_shot_captures_path(shot), params: { capture: { player_id: first.id, weight: 8 } }
    post admin_shot_captures_path(shot), params: { capture: { player_id: second.id, weight: 0 } }

    expect(shot.captures.pluck(:player_id, :weight)).to contain_exactly([first.id, 8], [second.id, 0])
    expect(first.photo_url).to eq("/icon.png")
    expect(second.photo_url).to be_nil
  end

  it "keeps generated samples out of image recognition" do
    player = create(:player)
    shot = Shot.create!(external_url: "/icon.png", tags: ["sample"])
    shot.captures.create!(player: player)

    expect(player.photo_url).to eq("/icon.png")
    expect(player.photo_url(recognition: true)).to be_nil
  end
end
