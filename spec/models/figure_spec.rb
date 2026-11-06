require "rails_helper"

RSpec.describe Figure do
  it "gives new athletes a separate identity without changing their athletic profile" do
    player = create :player, first_name: "Jordan", last_name: "Reyes", entity_code: "PLAYER-REYES_JORDAN"
    expect(player.figure.name).to eq("Jordan Reyes")
    expect(player.figure.entity_code).to eq("FIGURE-PLAYER-REYES_JORDAN")
    expect(player.figure.players).to eq([ player ])
    expect(player.reload.entity_code).to eq("PLAYER-REYES_JORDAN")
  end

  it "allows staff without athletic profiles and keeps same-name figures distinct" do
    first = create :figure, name: "Alex Morgan"
    second = create :figure, name: first.name
    expect(first.players).to be_empty
    expect(second).not_to eq(first)
  end

  it "holds several athletic profiles for a two-sport career" do
    football = create :player, first_name: "Deion", last_name: "Sanders"
    baseball = create :player, figure: football.figure
    expect(football.figure.players).to contain_exactly(football, baseball)
    expect(baseball.name).to eq("Deion Sanders")
    baseball.update! nicknames: [ "Prime Time" ]
    expect(football.reload.nicknames).to eq([ "Prime Time" ])
  end

  it "requires every athletic profile to belong to a figure at the database boundary" do
    player = create :player
    expect { player.update_column(:figure_id, nil) }.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "preserves a figure and their appointments when an athletic profile is rebuilt" do
    player = create :player, entity_code: "PLAYER-REYES_JORDAN"
    figure = player.figure
    tenure = create :staff_tenure, :broadcaster, figure: figure
    player.delete
    expect(figure.reload.players).to be_empty
    replacement = create :player, entity_code: "PLAYER-REYES_JORDAN"
    expect(replacement.figure).to eq(figure)
    expect(tenure.reload.figure).to eq(figure)
  end

  it "carries a rebuilt profile's new names onto the reclaimed figure" do
    player = create :player, entity_code: "PLAYER-REYES_JORDAN", first_name: "Jordan", last_name: "Reyes"
    figure = player.figure
    player.delete
    replacement = create :player, entity_code: "PLAYER-REYES_JORDAN", first_name: "Jordán", last_name: "Reyes"
    expect(replacement.figure).to eq(figure)
    expect(figure.reload.name).to eq("Jordán Reyes")
  end

  it "keeps career identity when a player transfers or changes their name" do
    player = create :player, last_name: "Reyes"
    original = player.figure
    player.update! team: create(:team), first_name: "Jordán"
    expect(player.figure.reload).to eq(original)
    expect(original.reload).to have_attributes(first_name: "Jordán", last_name: "Reyes", name: "Jordán Reyes")
  end

  it "holds the player's names and builds a trimmed display name from them" do
    player = create :player, first_name: "Pelé", last_name: nil, nicknames: [ "O Rei" ]
    expect(player.reload.figure).to have_attributes(first_name: "Pelé", last_name: nil, nicknames: [ "O Rei" ], name: "Pelé")
    expect(player.name).to eq("Pelé")
    expect(Player.matching_name("rei")).to eq([ player ])
    expect(create(:player, first_name: nil, last_name: " ").name).to eq(Figure::UNNAMED)
  end

  it "restricts deletion while appointments or athletic profiles refer to a figure" do
    tenure = create :staff_tenure
    expect(tenure.figure.destroy).to be_falsey
    expect(tenure.reload.figure).to be_persisted
    player = create :player
    expect(player.figure.destroy).to be_falsey
  end
end
