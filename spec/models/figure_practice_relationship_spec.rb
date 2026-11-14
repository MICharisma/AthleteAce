require "rails_helper"

RSpec.describe FigurePracticeRelationship do
  let(:walk) { create :protocol, name: "Morning walk" }
  let(:prayer) { create :practice, name: "Prayer" }
  let(:gratitude) { create :practice, name: "Gratitude" }
  let(:exercise) { create :practice, name: "Exercise" }

  def connect(relationship, *practices)
    practices.each { create :practice_connection, figure_practice_relationship: relationship, practice: it }
    relationship.reload
  end

  it "connects one protocol to several practices for one figure without classifying it for others" do
    athlete = connect(create(:figure_practice_relationship, protocol: walk,
      interpretation: "My morning walk is an example of prayer and gratitude."), gratitude, prayer)
    other = connect(create(:figure_practice_relationship, protocol: walk), exercise)
    expect(athlete.practices).to eq([ gratitude, prayer ])
    expect(other.practices).to eq([ exercise ])
    connect(athlete, create(:practice, name: "Breathwork"))
    expect(other.reload.practices).to eq([ exercise ])
  end

  it "keeps a figure's different historical descriptions as separate claims" do
    figure = create :figure
    early = connect(create(:figure_practice_relationship, figure: figure, protocol: walk, start_date: "2015",
      end_date: "2018", temporal_state: "historical"), exercise)
    later = connect(create(:figure_practice_relationship, figure: figure, protocol: walk, start_date: "2022"), prayer)
    expect(figure.figure_practice_relationships).to contain_exactly(early, later)
  end

  it "shares a practice across different meditation protocols" do
    meditation = create :practice, name: "Meditation"
    one = connect(create(:figure_practice_relationship, protocol: create(:protocol, name: "Box breathing")), meditation)
    two = connect(create(:figure_practice_relationship, protocol: create(:protocol, name: "Body scan")), meditation)
    expect(meditation.figure_practice_relationships).to contain_exactly(one, two)
  end

  it "allows broad-only and protocol-only claims but flags claims with no target" do
    broad = connect(create(:figure_practice_relationship, predicate: "recommends"), prayer)
    protocol_only = create :figure_practice_relationship, protocol: walk
    empty = create :figure_practice_relationship
    expect([ broad, protocol_only, empty ].map(&:targeted?)).to eq([ true, true, false ])
  end

  it "names a practice only once per claim" do
    relationship = connect(create(:figure_practice_relationship), prayer)
    duplicate = build :practice_connection, figure_practice_relationship: relationship, practice: prayer
    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "keeps doing, recommending, teaching and endorsing distinct" do
    figure = create :figure
    %w[participates_in endorses].each { create :figure_practice_relationship, figure: figure, protocol: walk, predicate: it }
    expect(figure.figure_practice_relationships.map(&:predicate)).to contain_exactly("participates_in", "endorses")
    expect(build(:figure_practice_relationship, predicate: "believes")).not_to be_valid
  end

  it "keeps same-name protocols and practices distinct" do
    create :protocol, name: "Morning walk"
    create :protocol, name: "Morning walk"
    expect(Protocol.where(name: "Morning walk").count).to eq(2)
  end
end
