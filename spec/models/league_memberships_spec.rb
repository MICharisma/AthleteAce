require "rails_helper"

RSpec.describe "League memberships", type: :model do
  let(:league) { create(:league) }
  let(:team) { create(:team, league: league) }
  let(:conference) { create(:conference, league: league) }

  it "attaches a team directly to its league without a conference or division" do
    membership = Membership.create!(team: team)

    expect(membership.reload.league).to eq(league)
    expect(membership.sport).to eq(league.sport)
    expect(membership.conference).to be_nil
    expect(membership.division).to be_nil
    expect(league.memberships).to include(membership)
    expect(league.sport.memberships).to include(membership)
    expect(league.jurisdiction.memberships).to include(membership)
    expect(league.teams).to include(team)
    expect(team.reload.conference).to be_nil
    expect(team.division).to be_nil
  end

  it "attaches a team to a conference without inventing a division" do
    membership = Membership.create!(team: team, conference: conference)

    expect(membership.reload.league).to eq(league)
    expect(membership.division).to be_nil
    expect(team.reload.conference).to eq(conference)
    expect(team.division).to be_nil
    expect(conference.memberships).to include(membership)
    expect(conference.teams).to eq([team])
  end

  it "attaches a team to a division directly under a league" do
    division = Division.create!(name: "North", league: league)
    membership = Membership.create!(team: team, division: division)

    expect(division.reload.conference).to be_nil
    expect(league.divisions).to include(division)
    expect(league.sport.divisions).to include(division)
    expect(membership.reload.league).to eq(league)
    expect(membership.conference).to be_nil
    expect(team.reload.division).to eq(division)
    expect(team.conference).to be_nil
    expect(division.teams).to eq([team])
  end

  it "infers league and conference for existing division-based callers" do
    division = Division.create!(name: "East", conference: conference)
    membership = Membership.create!(team: team, division: division)

    expect(division.reload.league).to eq(league)
    expect(membership.reload.league).to eq(league)
    expect(membership.conference).to eq(conference)
    expect(team.reload.division).to eq(division)
    expect(team.conference).to eq(conference)
    expect(conference.teams).to eq([team])
  end

  it "rejects conference and division links from another league" do
    other_conference = create(:conference)
    division = create(:division, conference: other_conference)

    expect(Division.new(name: "East", league: league, conference: other_conference)).not_to be_valid
    membership = Membership.new(team: team, league: league, conference: other_conference, division: division)
    expect(membership).not_to be_valid
    expect(membership.errors[:conference]).to be_present
    expect(membership.errors[:division]).to be_present
  end

  it "rejects a division from a different conference in the same league" do
    other_conference = create(:conference, league: league)
    membership = Membership.new(team: team, conference: conference, division: create(:division, conference: other_conference))

    expect(membership).not_to be_valid
    expect(membership.errors[:division]).to be_present
  end

  it "rejects placing a conference-free division inside a conference" do
    division = create(:division, league: league, conference: nil)

    expect(Membership.new(team: team, division: division, conference: conference)).not_to be_valid
  end

  it "retains an earlier league membership when a team moves leagues" do
    previous_conference = create(:conference)
    previous_division = create(:division, conference: previous_conference)
    historical = Membership.create!(team: team, division: previous_division, active: false,
      start_date: Date.new(2023, 7, 1), end_date: Date.new(2024, 6, 30))
    Membership.create!(team: team, conference: conference)

    expect(historical.reload.league).to eq(previous_conference.league)
    expect(previous_conference.memberships).to include(historical)
    expect(previous_conference.teams).to be_empty
    expect(previous_division.teams).to be_empty
    expect(team.reload.conference).to eq(conference)
    expect(team.league).to eq(league)
    historical.active = true
    expect(historical).not_to be_valid
  end

  it "preserves seasonal divisions that have no conference" do
    division = create(:division, league: league, conference: nil)
    campaign = Campaign.create!(team: team, season: create(:season, league: league), division: division)

    expect(campaign.reload.division).to eq(division)
    expect(campaign.conference).to be_nil
    campaign.division = create(:division, conference: nil)
    expect(campaign).not_to be_valid
  end

  it "includes conference-only affiliations and ungrouped leagues in geographic browsing" do
    stadium = create(:stadium)
    team.update!(stadium: stadium)
    Membership.create!(team: team, conference: conference)
    ungrouped_team = create(:team, stadium: stadium)

    [stadium, stadium.city, stadium.state].each do |location|
      expect(location.conferences).to include(conference)
      expect(location.leagues).to include(league, ungrouped_team.league)
    end
  end
end
