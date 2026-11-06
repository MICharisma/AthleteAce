require "rails_helper"
require Rails.root.join("lib/seed_helpers")
require Rails.root.join("db/seeds/seed_players")

RSpec.describe SeedPlayers do
  it "creates a Figure and reuses its player when a legacy roster is seeded again" do
    team = create :team, territory: "Oakland", mascot: "Herons"
    attributes = { "first_name" => "Jordan", "last_name" => "Reyes", "current_position" => "Guard" }
    allow(SeedHelpers).to receive(:log_and_puts)

    player = described_class.create_player(attributes, team)
    replay = described_class.create_player(attributes.merge("current_position" => "Forward"), team)

    expect(replay).to eq(player)
    expect(Player.count).to eq(1)
    expect(Figure.count).to eq(1)
    expect(player.reload.current_position).to eq("Forward")
    expect(player.figure).to have_attributes(first_name: "Jordan", last_name: "Reyes", name: "Jordan Reyes")
  end
end
