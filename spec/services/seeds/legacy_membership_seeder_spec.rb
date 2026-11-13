require "rails_helper"
require Rails.root.join("lib/seed_helpers")
require Rails.root.join("db/seeds/seed_memberships")

RSpec.describe SeedMemberships do
  it "imports mixed grouping levels within a league and replays without duplicates" do
    league = create(:league)
    conference = create(:conference, league: league)
    nested_division = create(:division, conference: conference)
    direct_division = create(:division, conference: nil, league: league)
    teams = create_list(:team, 4, league: league)
    create(:team, territory: teams.last.territory, mascot: teams.last.mascot)
    rows = [
      { "conference_name" => conference.name, "division_name" => nested_division.name },
      { "conference_name" => conference.name },
      { "division_name" => direct_division.name },
      {}
    ].each_with_index.map do |grouping, index|
      grouping.merge("territory_name" => teams[index].territory, "team_name" => teams[index].mascot,
        "start_year" => 2026, "active" => true)
    end
    allow(SeedHelpers).to receive(:log_and_puts)
    allow(SeedHelpers).to receive(:load_json_files).with("memberships.json").and_return([
      { path: SeedHelpers::SEED_DATA_ROOT.join("memberships.json"), data: { "league_name" => league.name, "memberships" => rows } }
    ])

    described_class.run(["memberships.json"])
    expect(league.memberships.count).to eq(4)
    expect(teams.map { |team| [team.reload.conference, team.division] }).to eq([
      [conference, nested_division], [conference, nil], [nil, direct_division], [nil, nil]
    ])
    original_ids = Membership.order(:id).pluck(:id)
    described_class.run(["memberships.json"])
    expect(Membership.order(:id).pluck(:id)).to eq(original_ids)
    expect(Membership.active.count).to eq(4)
  end
end
