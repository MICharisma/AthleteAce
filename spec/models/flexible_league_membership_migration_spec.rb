require "rails_helper"
require Rails.root.join("db/migrate/20261113010000_allow_flexible_league_memberships")

RSpec.describe AllowFlexibleLeagueMemberships, type: :model do
  let(:migration) { described_class.new }

  around do |example|
    original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = original_verbose
    Division.reset_column_information
    Membership.reset_column_information
  end

  it "backfills the original hierarchy without changing membership identity or history" do
    division = create(:division)
    team = create(:team, league: division.league)
    membership = Membership.create!(team: team, division: division, active: false,
      start_date: Date.new(2018, 7, 1), end_date: Date.new(2020, 6, 30), entity_code: "MEMBERSHIP-NORTH-2018")
    original = membership.attributes
    league_id = division.league_id
    conference_id = division.conference_id

    migration.migrate(:down)
    migration.migrate(:up)
    Division.reset_column_information
    Membership.reset_column_information

    expect(division.reload.league_id).to eq(league_id)
    expect(membership.reload.attributes).to eq(original)
    expect(membership.conference_id).to eq(conference_id)
    expect(membership.league_id).to eq(league_id)
  end

  it "refuses a rollback that would discard a membership without a division" do
    membership = Membership.create!(team: create(:team))

    expect { migration.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration)
    expect(membership.reload.division).to be_nil
    expect(membership.league).to be_present
  end

  it "refuses a rollback that would discard a division without a conference" do
    division = create(:division, conference: nil)

    expect { migration.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration)
    expect(division.reload.conference).to be_nil
    expect(division.league).to be_present
  end
end
