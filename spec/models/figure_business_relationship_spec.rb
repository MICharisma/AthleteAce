require "rails_helper"

RSpec.describe FigureBusinessRelationship do
  it "keeps owning and promoting the same business as independent claims" do
    figure = create :figure
    business = create :business
    owns = create :figure_business_relationship, figure: figure, business: business, predicate: "owns", start_date: "2019"
    promotes = create :figure_business_relationship, figure: figure, business: business, predicate: "promotes", start_date: "2021-03"
    expect(figure.figure_business_relationships).to contain_exactly(owns, promotes)
    expect(figure.businesses).to eq([ business ])
    expect(figure.figure_business_relationships.invests_in).to be_empty
  end

  it "keeps a founding as history after the founder no longer owns the business" do
    figure = create :figure
    business = create :business, founded_year: 2012
    founded = create :figure_business_relationship, figure: figure, business: business, predicate: "founded",
      start_date: "2012", temporal_state: "historical"
    create :figure_business_relationship, figure: figure, business: business, predicate: "owns",
      start_date: "2012", end_date: "2020-06", temporal_state: "historical"
    expect(founded).to be_valid
    expect(build(:figure_business_relationship, predicate: "founded", end_date: "2020")).not_to be_valid
    expect(build(:figure_business_relationship, :reported_current, predicate: "founded")).not_to be_valid
  end

  it "lets two figures share a business, including a foundation and a school" do
    foundation = create :business, :foundation
    school = create :business, :school
    first, second = create_list(:figure, 2)
    [ first, second ].each { create :figure_business_relationship, figure: it, business: foundation, predicate: "founded" }
    create :figure_business_relationship, figure: first, business: school, predicate: "endorses"
    expect(foundation.figures).to contain_exactly(first, second)
    expect(school.figures).to eq([ first ])
  end

  it "records compensation as documented or unknown, never assuming unpaid" do
    paid = create :figure_business_relationship, :paid_sponsorship
    undisclosed = create :figure_business_relationship, predicate: "sponsored_by"
    expect(paid).to be_compensation_documented_paid
    expect(undisclosed).to be_compensation_unknown
    expect(build(:figure_business_relationship, predicate: "owns", compensation: "documented_paid")).not_to be_valid
    expect(build(:figure_business_relationship, compensation: "free")).not_to be_valid
  end

  it "requires dated evidence for current claims and never infers current from a missing end" do
    expect(build(:figure_business_relationship, :reported_current)).to be_valid
    expect(build(:figure_business_relationship, temporal_state: "reported_current")).not_to be_valid
    expect(build(:figure_business_relationship, :reported_current, end_date: "2026")).not_to be_valid
    open_ended = create :figure_business_relationship, start_date: "2018"
    expect(open_ended).to be_unknown
    expect(build(:figure_business_relationship, temporal_state: "planned", start_date: "2027", end_date: "2028")).not_to be_valid
  end

  it "preserves partial dates and rejects reversed or invalid ones" do
    tie = create :figure_business_relationship, start_date: "2024", end_date: "2025-02"
    expect(tie.reload.attributes.values_at("start_date", "end_date")).to eq(%w[2024 2025-02])
    expect(build(:figure_business_relationship, start_date: "2025", end_date: "2024-12-31")).not_to be_valid
    expect(build(:figure_business_relationship, start_date: "2025-02-29")).not_to be_valid
    expect(build(:figure_business_relationship, as_of_date: "recently")).not_to be_valid
  end

  it "keeps same-name businesses and figures distinct" do
    one = create :business, name: "Summit Coffee"
    other = create :business, name: "Summit Coffee"
    expect(Business.where(name: "Summit Coffee")).to contain_exactly(one, other)
  end

  it "rejects duplicate codes, including at the database" do
    tie = create :figure_business_relationship
    expect(build(:figure_business_relationship, entity_code: tie.entity_code)).not_to be_valid
    duplicate = build :figure_business_relationship, entity_code: tie.entity_code
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "investments" do
    it "is its own predicate, independent of promotion" do
      investment = create :figure_business_relationship, predicate: "invests_in", start_date: "2022"
      expect(investment).to be_invests_in
      expect(investment.figure.figure_business_relationships.promotes).to be_empty
    end

    it "names a fund or holding vehicle only on investments, with no amounts" do
      expect(build(:figure_business_relationship, predicate: "invests_in", vehicle_name: "Harbor Ventures Fund II",
        context: "Invested through the fund, per the fund's portfolio page")).to be_valid
      expect(build(:figure_business_relationship, predicate: "promotes", vehicle_name: "Harbor Ventures")).not_to be_valid
      expect(described_class.column_names.grep(/amount|percent|valuation|stake/)).to be_empty
    end

    it "keeps historical exits" do
      exit = create :figure_business_relationship, predicate: "invests_in", start_date: "2016", end_date: "2021-09",
        temporal_state: "historical"
      expect(exit.reload).to be_historical
    end
  end
end
