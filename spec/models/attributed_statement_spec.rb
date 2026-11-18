require "rails_helper"

RSpec.describe AttributedStatement do
  it "distinguishes quotes, paraphrases, self-stated values and observer characterizations" do
    figure = create :figure
    %w[direct_quote attributed_paraphrase self_stated_value].each do |kind|
      expect(build(:attributed_statement, figure: figure, attribution_kind: kind)).to be_valid
    end
    expect(build(:attributed_statement, :observer_characterization, figure: figure)).to be_valid
    expect(build(:attributed_statement, attribution_kind: "rumor")).not_to be_valid
  end

  it "names the observer separately from the figure described" do
    coach = create :figure
    characterization = create :attributed_statement, :observer_characterization, observer: coach, observer_name: nil
    expect(characterization.observer).to eq(coach)
    expect(coach.observed_statements).to eq([ characterization ])
    expect(build(:attributed_statement, :observer_characterization, observer_name: nil)).not_to be_valid
    expect(build(:attributed_statement, observer_name: "A reporter")).not_to be_valid
    expect(build(:attributed_statement, :observer_characterization, figure: coach, observer: coach)).not_to be_valid
  end

  it "links a teaching to the same figure's practice relationship, or none" do
    relationship = create :figure_practice_relationship, protocol: create(:protocol)
    expect(build(:attributed_statement, figure: relationship.figure, figure_practice_relationship: relationship)).to be_valid
    expect(build(:attributed_statement, figure_practice_relationship: relationship)).not_to be_valid
    expect(build(:attributed_statement)).to be_valid
  end

  it "keeps historical staff context on the same figure" do
    tenure = create :staff_tenure, start_date: "2014", end_date: "2016"
    expect(build(:attributed_statement, figure: tenure.figure, staff_tenure: tenure)).to be_valid
    expect(build(:attributed_statement, staff_tenure: tenure)).not_to be_valid
  end

  it "preserves exact Unicode wording, qualifiers and partial dates" do
    text = "«Je crois que la discipline, au fond, c'est de la liberté» — probably my best advice."
    statement = create :attributed_statement, text: text, statement_date: "2019-05"
    expect(statement.reload.text).to eq(text)
    expect(statement.statement_date).to eq("2019-05")
    expect(build(:attributed_statement, statement_date: "May 2019")).not_to be_valid
  end

  it "organizes several figures' statements under one topic" do
    topic = create :topic, name: "Discipline"
    statements = create_list(:attributed_statement, 2, topic: topic)
    expect(topic.attributed_statements).to match_array(statements)
    expect(statements.map(&:figure).uniq.size).to eq(2)
    expect(build(:topic, name: "Discipline")).not_to be_valid
  end
end
