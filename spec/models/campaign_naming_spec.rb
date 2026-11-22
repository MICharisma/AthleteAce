require "rails_helper"

RSpec.describe Campaign, type: :model do
  let(:team) { create :team, territory: "Las Vegas", mascot: "Raiders", stadium: create(:stadium) }
  let(:season) { create :season, league: team.league, start_date: "2010-09-12", end_date: "2011-01-02" }
  let(:coliseum) { create :stadium, name: "Oakland Coliseum" }

  before do
    TeamNaming.create! team: team, territory: "Oakland", nickname: Nickname.create!(text: "Raiders"), end_date: "2020-01-21"
    Tenancy.create! team: team, stadium: coliseum, end_date: "2019-12-15"
  end

  it "prefers its own recorded name, then the naming in force when its season started" do
    expect(described_class.create!(team: team, season: season, display_name: "Oakland Raiders (recorded)").name).to eq("Oakland Raiders (recorded)")
    expect(described_class.new(team: team, season: season).name).to eq("Oakland Raiders")
  end

  it "uses the team's current values when its season has no start date" do
    expect(described_class.new(team: team, season: create(:season, league: team.league)).name).to eq("Las Vegas Raiders")
  end

  it "finds its home stadium and city through the tenancy unless it records its own" do
    campaign = described_class.new(team: team, season: season)
    expect(campaign.home_stadium).to eq(coliseum)
    expect(campaign.home_city).to eq(coliseum.city)
    expect(described_class.new(team: team, season: create(:season, league: team.league)).home_stadium).to be_nil
    bubble = create :stadium
    expect(described_class.new(team: team, season: season, stadium: bubble).home_stadium).to eq(bubble)
  end
end
