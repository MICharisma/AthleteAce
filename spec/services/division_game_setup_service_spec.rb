require "rails_helper"

RSpec.describe DivisionGameSetupService do
  it "offers divisions without conferences at league difficulty" do
    league = create(:league)
    divisions = create_list(:division, 2, league: league, conference: nil)
    team = create(:team, league: league)
    Membership.create!(team: team, division: divisions.first)
    setup = described_class.new(difficulty: :league).call

    expect(setup.team).to eq(team)
    expect(setup.choices).to match_array(divisions)
    expect(setup.correct_division).to eq(divisions.first)
    expect(described_class.new(difficulty: :conference).call).to be_nil
  end

  it "keeps teams without divisions out of division questions" do
    team = create(:team)
    Membership.create!(team: team, conference: create(:conference, league: team.league))

    expect(described_class.new(difficulty: :league).call).to be_nil
  end
end
