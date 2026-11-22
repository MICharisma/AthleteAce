require "rails_helper"

RSpec.describe TeamNaming, type: :model do
  let(:team) { create :team, territory: "Las Vegas", mascot: "Raiders" }
  let(:raiders) { Nickname.create! text: "Raiders" }

  it "names a team from its territory and shared nickname, or an override" do
    expect(described_class.new(team: team, territory: "Oakland", nickname: raiders).name).to eq("Oakland Raiders")
    expect(described_class.new(team: team, territory: "Washington", display_name: "Washington Football Team").name).to eq("Washington Football Team")
  end

  it "shares one nickname row across teams regardless of case" do
    expect(Nickname.new(text: " #{raiders.text.downcase} ")).not_to be_valid
    described_class.create! team: create(:team), nickname: raiders, territory: "Los Angeles"
    described_class.create! team: team, nickname: raiders, territory: "Oakland"
    expect(raiders.teams.count).to eq(2)
  end

  it "rejects overlapping namings for one team, in the model and the database" do
    described_class.create! team: team, nickname: raiders, territory: "Oakland", start_date: "1995-07-01", end_date: "2020-01-21"
    overlapping = described_class.new(team: team, nickname: raiders, territory: "Las Vegas", start_date: "2019-01-01")
    expect(overlapping).not_to be_valid
    expect { overlapping.save! validate: false }.to raise_error(ActiveRecord::StatementInvalid, /team_namings_do_not_overlap/)
    expect(described_class.new(team: team, nickname: raiders, territory: "Las Vegas", start_date: "2020-01-22")).to be_valid
  end

  it "gives a team its name on a date, falling back to the cached current name" do
    described_class.create! team: team, nickname: raiders, territory: "Oakland", start_date: "1995-07-01", end_date: "2020-01-21"
    expect(team.name_on(Date.new(2010, 1, 1))).to eq("Oakland Raiders")
    expect(team.name_on(Date.new(2023, 1, 1))).to eq("Las Vegas Raiders")
    expect(team.name_on(nil)).to eq("Las Vegas Raiders")
  end
end
