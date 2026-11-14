require "rails_helper"

RSpec.describe Attestation do
  it "supports text, link, image and video forms with a payload each" do
    expect(build(:attestation, :text)).to be_valid
    expect(build(:attestation)).to be_valid
    expect(build(:attestation, :video)).to be_valid
    expect(build(:attestation, content_form: "image", url: nil, media_url: "https://example.com/photo.jpg")).to be_valid
    expect(build(:attestation, :text, body: "")).not_to be_valid
    expect(build(:attestation, url: nil)).not_to be_valid
    expect(build(:attestation, content_form: "video", url: nil, media_url: nil)).not_to be_valid
    expect(build(:attestation, content_form: "audio")).not_to be_valid
  end

  it "keeps the claim's figure, the author, the publisher and the entering ace apart" do
    ace = create :ace
    tie = create :figure_business_relationship
    athlete_authored = create :attestation, claim: tie, author: tie.figure, entered_by: ace
    reporter = create :attestation, claim: tie, author: nil, author_name: "Dana Ortiz", publisher: "Example Sports Daily", entered_by: ace
    expect(athlete_authored.author).to eq(tie.figure)
    expect(reporter.author_name).to eq("Dana Ortiz")
    expect(reporter.entered_by).to eq(ace)
    expect(reporter.author).to be_nil
    expect(tie.attestations).to contain_exactly(athlete_authored, reporter)
  end

  it "leaves unknown authorship and dates unknown" do
    attestation = create :attestation, author: nil, author_name: nil, published_on: nil
    expect(attestation.reload.attributes.values_at("author_id", "author_name", "published_on")).to all(be_nil)
    expect(build(:attestation, published_on: "2025-07")).to be_valid
    expect(build(:attestation, published_on: "last July")).not_to be_valid
  end

  it "cites different passages of one URL in separately coded attestations" do
    url = "https://example.com/interviews/long-form"
    statement = create :attributed_statement
    tie = create :figure_business_relationship, figure: statement.figure
    one = create :attestation, claim: statement, url: url, locator: "paragraph 4"
    two = create :attestation, claim: tie, url: url, locator: "paragraph 11"
    expect([ one, two ].map(&:entity_code).uniq.size).to eq(2)
  end

  it "supports only the three claim types" do
    relationship = create :figure_practice_relationship
    expect(build(:attestation, :text, claim: relationship)).to be_valid
    expect(build(:attestation, claim: create(:staff_tenure))).not_to be_valid
  end

  it "is complete only with a traceable source and explanatory context" do
    expect(build(:attestation)).to be_complete
    expect(build(:attestation, context: nil)).not_to be_complete
    expect(build(:attestation, :text, source_title: nil)).not_to be_complete
  end
end
