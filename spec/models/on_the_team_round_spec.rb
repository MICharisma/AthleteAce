require "rails_helper"

RSpec.describe OnTheTeamRound do
  let(:league) { create(:league) }
  let(:focus) { create(:team, league: league, territory: "Orlando", mascot: "Magic") }
  let!(:rival) { create(:team, league: league, territory: "Miami", mascot: "Heat") }
  let(:members) { create_list(:player, 4, team: focus) }
  let(:decoys) { create_list(:player, 4, team: rival) }

  it "mixes roster yes questions with league decoy no questions" do
    questions = described_class.new(focus_team: focus, members: members, decoys: decoys).questions(length: 6)

    expect(questions.size).to eq(6)
    expect(questions.count { |question| question.fetch(:on_team) }).to be_between(1, 5)
    expect(questions.count { |question| !question.fetch(:on_team) }).to be_between(1, 5)
    questions.each do |question|
      expect(question.fetch(:choices).map { |choice| choice.fetch(:name) }).to contain_exactly("Yes", "No")
      expect(question.fetch(:focus_team_id)).to eq(focus.id)
      expect(question.fetch(:target_name)).to eq(question.fetch(:on_team) ? "Yes" : "No")
      expect(question.fetch(:correct_choice_id)).to eq(
        question.fetch(:choices).find { |choice| choice.fetch(:name) == question.fetch(:target_name) }.fetch(:id)
      )
    end
  end

  it "needs members, decoys, and another league team" do
    expect(described_class.new(focus_team: focus, members: members, decoys: []).available_count).to eq(0)
    expect(described_class.new(focus_team: focus, members: [], decoys: decoys).available_count).to eq(0)
  end
end
