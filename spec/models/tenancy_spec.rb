require "rails_helper"

RSpec.describe Tenancy, type: :model do
  let(:home) { create :stadium, name: "Oakland Coliseum" }
  let(:team) { create :team, stadium: create(:stadium, name: "Las Vegas Ballpark") }

  before { described_class.create! team: team, stadium: home, start_date: "1968-04-17", end_date: "2024-09-26" }

  it "rejects overlapping home tenancies for one team, in the model and the database" do
    overlapping = described_class.new(team: team, stadium: create(:stadium), start_date: "2024-01-01")
    expect(overlapping).not_to be_valid
    expect { overlapping.save! validate: false }.to raise_error(ActiveRecord::StatementInvalid, /home_tenancies_do_not_overlap/)
  end

  it "allows a temporary tenancy inside a home range and other teams in the same stadium" do
    expect(described_class.new(team: team, stadium: create(:stadium), role: "temporary", start_date: "2020-07-01", end_date: "2020-10-01")).to be_valid
    expect(described_class.new(team: create(:team), stadium: home, start_date: "1995-07-01")).to be_valid
  end

  it "rejects an unknown role" do
    expect(described_class.new(team: team, stadium: home, role: "neutral")).not_to be_valid
  end

  it "gives a team its home stadium on a date, without guessing from today's stadium" do
    described_class.create! team: team, stadium: create(:stadium), role: "temporary", start_date: "2020-07-01", end_date: "2020-10-01"
    expect(team.stadium_on(Date.new(2020, 8, 1))).to eq(home)
    expect(team.stadium_on(Date.new(2025, 4, 1))).to be_nil
  end
end
