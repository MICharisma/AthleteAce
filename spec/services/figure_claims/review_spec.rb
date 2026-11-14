require "rails_helper"

RSpec.describe FigureClaims::Review do
  let(:admin) { create :ace, :admin }
  let(:claim) { create(:attestation, claim: create(:figure_business_relationship)).claim.reload }

  def review(action, record = claim, actor: admin, **overrides)
    described_class.call(claim: record, actor: actor, action: action, revision: record.moderation_revision,
      status: record.moderation_status, digest: record.review_digest, **overrides)
  end

  it "lets only active admins publish, including their own entries" do
    [ create(:ace), create(:ace, moderator: true), create(:ace, :admin, suspended_at: Time.current), nil ].each do |actor|
      expect { review("publish", actor: actor) }.to raise_error(described_class::Forbidden)
    end
    claim.attestations.first.update! entered_by: admin
    review("publish")
    expect(claim.reload).to be_published
    expect(claim.moderation_decisions.last).to have_attributes(action: "approved", actor: admin, reason: "Trusted admin publication")
  end

  it "refuses publication without complete evidence or a target" do
    bare = create :figure_business_relationship
    expect { review("publish", bare) }.to raise_error(described_class::Conflict, /at least one Attestation/)
    create :attestation, claim: bare, context: nil
    expect { review("publish", bare.reload) }.to raise_error(described_class::Conflict, /traceable source and context/)
    empty = create :figure_practice_relationship
    create :attestation, :text, claim: empty
    expect { review("publish", empty.reload) }.to raise_error(described_class::Conflict, /Protocol or at least one Practice/)
  end

  it "refuses a stale preview of a changed revision or practice set" do
    practice_claim = create :figure_practice_relationship, protocol: create(:protocol)
    create :attestation, :text, claim: practice_claim
    practice_claim.reload
    stale = { revision: practice_claim.moderation_revision, status: "pending", digest: practice_claim.review_digest }
    create :practice_connection, figure_practice_relationship: practice_claim
    expect { described_class.call(claim: practice_claim.reload, actor: admin, action: "publish", **stale) }
      .to raise_error(described_class::Conflict)
    expect(practice_claim.reload).to be_pending
  end

  it "refuses a digest from before an identity rename even at the same revision" do
    digest = claim.review_digest
    claim.business.update! name: "Renamed Co"
    expect { review("publish", digest: digest) }.to raise_error(described_class::Conflict, /changed since your preview/)
  end

  it "records one decision for repeated submissions" do
    revision, digest = claim.moderation_revision, claim.review_digest
    review("publish")
    expect { described_class.call(claim: claim, actor: admin, action: "publish", revision: revision, status: "pending", digest: digest) }
      .to raise_error(described_class::Conflict)
    expect(claim.moderation_decisions.where(action: "approved").count).to eq(1)
  end

  it "withdraws and rejects only with a reason, and reopens" do
    expect { review("reject", reason: "") }.to raise_error(ArgumentError)
    review("publish")
    expect { review("withdraw", claim.reload) }.to raise_error(ArgumentError)
    review("withdraw", claim.reload, reason: "The source retracted the partnership.")
    expect(claim.reload).to have_attributes(moderation_status: "hidden")
    review("reopen", claim)
    review("reject", claim.reload, reason: "Only a photo; doesn't show a promotion.")
    expect(claim.reload.moderation_decisions.pluck(:action)).to eq(%w[approved hidden reopened rejected])
  end

  it "keeps a review decision when the importer replays the claim unchanged" do
    records = [
      { "type" => "Figure", "code" => "FIGURE-REVIEW_TEST", "attributes" => { "name" => "Review Test" } },
      { "type" => "Business", "code" => "BUSINESS-REVIEW_TEST", "attributes" => { "name" => "Review Test Co" } },
      { "type" => "FigureBusinessRelationship", "code" => "BUSINESS_TIE-REVIEW_TEST", "attributes" => { "predicate" => "owns" },
        "references" => { "figure" => "FIGURE-REVIEW_TEST", "business" => "BUSINESS-REVIEW_TEST" } },
      { "type" => "Attestation", "code" => "ATTESTATION-REVIEW_TEST",
        "attributes" => { "content_form" => "link", "url" => "https://example.com/r", "context" => "Lists the owner." },
        "references" => { "claim" => "BUSINESS_TIE-REVIEW_TEST" } }
    ]
    import = lambda do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "r.yaml")
        File.write(path, YAML.dump("format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records))
        Seeds::LibraryImporter.new.call([ path ])
      end
    end
    import.call
    imported = FigureBusinessRelationship.sole
    review("reject", imported, reason: "Not supported")
    import.call
    expect(imported.reload).to have_attributes(moderation_status: "rejected", moderation_revision: 1)
    records << records.last.deep_dup.merge("code" => "ATTESTATION-REVIEW_TEST-2")
    import.call
    expect(imported.reload).to have_attributes(moderation_status: "pending", moderation_revision: 2)
    records[2]["attributes"]["moderation_status"] = "approved"
    expect { import.call }.to raise_error(Seeds::LibraryImporter::Error, /unsupported/)
  end
end
