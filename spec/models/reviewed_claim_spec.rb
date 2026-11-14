require "rails_helper"

RSpec.describe ReviewedClaim do
  let(:admin) { create :ace, :admin }

  def publish(claim)
    claim.reload
    FigureClaims::Review.call(claim: claim, actor: admin, action: "publish", revision: claim.moderation_revision,
      status: claim.moderation_status, digest: claim.review_digest)
    claim.reload
  end

  def published_practice_claim
    claim = create :figure_practice_relationship, protocol: create(:protocol)
    create :practice_connection, figure_practice_relationship: claim, practice: create(:practice, name: "Prayer")
    create :attestation, :text, claim: claim
    publish claim
  end

  it "starts every claim pending, including imported ones" do
    expect(create(:figure_business_relationship)).to have_attributes(moderation_status: "pending", moderation_revision: 1)
    expect(FigureBusinessRelationship.published).to be_empty
  end

  it "returns a published claim to pending when its own fields change" do
    tie = create :figure_business_relationship, :paid_sponsorship
    create :attestation, claim: tie
    publish tie
    tie.update! start_date: "2024"
    expect(tie.reload).to have_attributes(moderation_status: "pending", moderation_revision: 3)
    expect(tie.moderation_decisions.last).to have_attributes(action: "submitted", from_status: "approved")
    expect(FigureBusinessRelationship.published).to be_empty
  end

  it "treats a changed predicate or business target as a material edit" do
    tie = create :figure_business_relationship
    create :attestation, claim: tie
    publish tie
    tie.update! business: create(:business)
    expect(tie.reload).to be_pending
    expect(tie.review_snapshot.dig("targets", "business", "entity_code")).to eq(tie.business.entity_code)
  end

  it "returns to pending when an attestation is added, changed or removed" do
    tie = create :figure_business_relationship
    evidence = create :attestation, claim: tie
    [ -> { create :attestation, :video, claim: tie }, -> { evidence.update! locator: "paragraph 9" },
      -> { evidence.update! author_name: "Another reporter" }, -> { evidence.destroy! } ].each do |change|
      publish tie
      change.call
      expect(tie.reload).to be_pending
    end
    expect(Attestation.published).to be_empty
  end

  it "returns to pending when a practice is added or removed or the interpretation changes" do
    claim = published_practice_claim
    create :practice_connection, figure_practice_relationship: claim, practice: create(:practice, name: "Gratitude")
    expect(claim.reload).to be_pending
    publish claim
    claim.practice_connections.first.destroy!
    expect(claim.reload).to be_pending
    publish claim
    claim.update! interpretation: "My walk is how I give thanks."
    expect(claim.reload).to be_pending
  end

  it "returns claims to pending when their protocol's method is rewritten" do
    claim = published_practice_claim
    claim.protocol.update! routine: "Twenty minutes, barefoot, at sunrise"
    expect(claim.reload).to be_pending
  end

  it "counts several changes in one transaction as one revision" do
    tie = create :figure_business_relationship
    create :attestation, claim: tie
    publish tie
    FigureBusinessRelationship.transaction do
      tie.update! context: "Updated context"
      create :attestation, claim: tie
      tie.attestations.first.update! excerpt: "a new passage"
    end
    expect(tie.reload.moderation_revision).to eq(3)
    expect(tie.moderation_decisions.where(action: "submitted").count).to eq(1)
  end

  it "exposes only the evidence of published claims" do
    published = create :figure_business_relationship
    shown = create :attestation, claim: published
    publish published
    hidden = create :attestation, claim: create(:figure_business_relationship)
    expect(Attestation.published).to eq([ shown ])
    expect(Attestation.published).not_to include(hidden)
  end

  it "snapshots the exact practice set, protocol method and evidence" do
    claim = published_practice_claim
    snapshot = claim.moderation_decisions.find_by!(action: "approved").snapshot
    expect(snapshot.dig("targets", "practices").map { it["name"] }).to eq([ "Prayer" ])
    expect(snapshot.dig("targets", "protocol", "routine")).to eq(claim.protocol.routine)
    expect(snapshot["attestations"].sole["body"]).to include("prayer and gratitude")
  end
end
