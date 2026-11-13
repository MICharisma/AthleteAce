require "rails_helper"

RSpec.describe PositionAssignment do
  let(:league) { create(:league) }
  let(:sport) { league.sport }
  let(:season) { create(:season, league: league) }
  let(:team) { create(:team, league: league) }
  let(:campaign) { Campaign.create!(team: team, season: season) }
  let(:player) { create(:player, team: team, sport: sport) }
  let(:left_field) { create(:position, sport: sport, name: "Left field", abbreviation: "LF") }
  let(:first_base) { create(:position, sport: sport, name: "First base", abbreviation: "1B") }
  let(:pinch_hitter) { create(:position, sport: sport, name: "Pinch hitter", abbreviation: "PH") }

  def roster_entry(effective_on:)
    roster = Roster.create!(campaign: campaign, kind: "observed", effective_on: effective_on)
    RosterEntry.create!(roster: roster, player: player)
  end

  def appearance(name: "Game")
    game = Contest.create!(name: name, kind: "game", context: league, season: season)
    Appearance.create!(player: player, contestant: Contestant.create!(contest: game, campaign: campaign))
  end

  it "orders positions within a game and lets a position recur" do
    played = appearance
    [ pinch_hitter, left_field, first_base, left_field ].each.with_index(1) do |position, sequence|
      played.position_assignments.create!(position: position, sequence: sequence)
    end
    expect(played.position_assignments.in_order.map { it.position.abbreviation }).to eq(%w[PH LF 1B LF])
    expect(played.position_assignments.new(position: first_base, sequence: 2)).not_to be_valid
    expect { PositionAssignment.insert_all!([ { subject_type: "Appearance", subject_id: played.id, position_id: first_base.id, sequence: 2, created_at: Time.current, updated_at: Time.current } ]) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "keeps unsequenced positions unique and allows one primary per subject" do
    entry = roster_entry(effective_on: Date.new(2026, 11, 1))
    entry.position_assignments.create!(position: left_field, primary: true)
    expect(entry.position_assignments.new(position: left_field)).not_to be_valid
    expect(entry.position_assignments.new(position: first_base, primary: true)).not_to be_valid
    expect(entry.position_assignments.create!(position: first_base)).to be_persisted
  end

  it "rejects positions from another sport and unknown subjects" do
    foreign = create(:position)
    expect(player.position_assignments.new(position: foreign)).not_to be_valid
    expect(PositionAssignment.new(subject: team, position: left_field)).not_to be_valid
  end

  it "derives a primary position from a career summary, then the latest roster, then games played" do
    expect(player.primary_position).to be_nil

    2.times { |n| appearance(name: "Game #{n}").position_assignments.create!(position: first_base, sequence: 1) }
    appearance(name: "Game 3").position_assignments.create!(position: left_field, sequence: 1)
    expect(player.primary_position).to eq(first_base)

    roster_entry(effective_on: Date.new(2025, 4, 1)).position_assignments.create!(position: first_base)
    roster_entry(effective_on: Date.new(2026, 4, 1)).position_assignments.create!(position: left_field)
    expect(player.primary_position).to eq(left_field)

    player.add_position(pinch_hitter, primary: true)
    expect(player.primary_position).to eq(pinch_hitter)
    expect(player.observed_positions).to contain_exactly(first_base, left_field, pinch_hitter)
    expect(player.secondary_positions).to contain_exactly(first_base, left_field)
  end

  it "groups positions under a parent in the same sport without loops" do
    outfield = create(:position, sport: sport, name: "Outfield", abbreviation: "OF")
    left_field.update!(parent: outfield)
    expect(outfield.children).to eq([ left_field ])
    expect(outfield.update(parent: left_field)).to be(false)
    expect(build(:position, parent: outfield)).not_to be_valid
    expect(build(:position, sport: sport, kind: "routine")).not_to be_valid
    expect(build(:position, sport: sport, kind: "apparatus")).to be_valid
  end
end
