require "rails_helper"

RSpec.describe "Admin Figure claims", type: :request do
  let(:admin) { create :ace, :admin }
  let(:figure) { create :figure, name: "Jordan Reyes", entity_code: "FIGURE-REYES_JORDAN" }
  let!(:walk) { create :protocol, name: "Morning walk", entity_code: "PROTOCOL-MORNING_WALK" }
  let!(:prayer) { create :practice, name: "Prayer" }
  let!(:gratitude) { create :practice, name: "Gratitude" }

  def create_walk_claim
    post admin_create_figure_claim_path("practice"), params: { claim: {
      entity_code: "PRACTICE_TIE-REYES-WALK", figure_code: figure.entity_code, predicate: "participates_in",
      protocol_id: walk.id, practice_ids: [ "", prayer.id, gratitude.id ], temporal_state: "unknown",
      interpretation: "My morning walk is prayer and gratitude." } }
    FigurePracticeRelationship.find_by!(entity_code: "PRACTICE_TIE-REYES-WALK")
  end

  def add_video(claim)
    post admin_claim_attestations_path("practice", claim), params: { attestation: {
      entity_code: "ATTESTATION-REYES-WALK", content_form: "video", url: "https://example.com/videos/reyes",
      locator: "02:10-02:45", author_code: figure.entity_code, publisher: "Example Sports Daily",
      published_on: "2025-03", context: "Reyes describes his walk as prayer and gratitude." } }
  end

  def publish(claim, **overrides)
    claim.reload
    post admin_review_figure_claim_path("practice", claim), params: { review_action: "publish",
      revision: claim.moderation_revision, status: claim.moderation_status, digest: claim.review_digest }.merge(overrides)
  end

  it "limits every page and action to admins" do
    claim = create :figure_practice_relationship
    [ nil, create(:ace), create(:ace, moderator: true) ].each do |viewer|
      sign_in viewer if viewer
      get admin_figure_claims_path
      expect(response).to have_http_status(viewer ? :see_other : :found)
      post admin_review_figure_claim_path("practice", claim), params: { review_action: "publish", revision: 1, status: "pending" }
      post admin_create_claim_identity_path("business"), params: { record: { name: "Sneaky Co" } }
    end
    expect(claim.reload).to be_pending
    expect(Business.count).to eq(0)
    sign_in admin
    get admin_figure_claims_path
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("private", "no-store")
  end

  it "records one association naming two practices, adds an athlete video, and publishes it" do
    sign_in admin
    claim = create_walk_claim
    expect(claim.practices).to eq([ gratitude, prayer ])
    expect(claim).to be_pending
    add_video(claim)
    attestation = claim.attestations.sole
    expect(attestation).to have_attributes(author: figure, entered_by: admin, content_form: "video")
    expect(attestation.captured_at).to be_present
    get admin_figure_claim_path("practice", claim)
    expect(response.body).to include("02:10-02:45", "Gratitude and Prayer")
    publish claim
    expect(response).to redirect_to(admin_figure_claim_path("practice", claim))
    expect(claim.reload).to be_published
  end

  it "returns a published claim to pending when its practice set changes, and refuses the stale preview" do
    sign_in admin
    claim = create_walk_claim
    add_video(claim)
    publish claim
    stale = { revision: claim.reload.moderation_revision, status: "pending", digest: claim.review_digest }
    patch admin_figure_claim_path("practice", claim), params: { revision: claim.moderation_revision, claim: {
      figure_code: figure.entity_code, predicate: "participates_in", protocol_id: walk.id, practice_ids: [ "", prayer.id ],
      temporal_state: "unknown", interpretation: "My morning walk is prayer and gratitude." } }
    expect(claim.reload).to be_pending
    expect(claim.practices).to eq([ prayer ])
    post admin_review_figure_claim_path("practice", claim), params: { review_action: "publish" }.merge(stale)
    expect(response).to have_http_status(:conflict)
    expect(claim.reload).to be_pending
  end

  it "rejects a stale edit form instead of overwriting a newer revision" do
    sign_in admin
    claim = create_walk_claim
    old_revision = claim.moderation_revision
    add_video(claim)
    patch admin_figure_claim_path("practice", claim), params: { revision: old_revision, claim: {
      figure_code: figure.entity_code, predicate: "endorses", temporal_state: "unknown" } }
    expect(response).to have_http_status(:conflict)
    expect(claim.reload.predicate).to eq("participates_in")
  end

  it "won't duplicate a claim on a repeated submission" do
    sign_in admin
    create_walk_claim
    create_walk_claim
    expect(response).to have_http_status(:unprocessable_content)
    expect(FigurePracticeRelationship.count).to eq(1)
  end

  it "requires a reason to withdraw and keeps history" do
    sign_in admin
    claim = create_walk_claim
    add_video(claim)
    publish claim
    claim.reload
    post admin_review_figure_claim_path("practice", claim), params: { review_action: "withdraw", revision: claim.moderation_revision,
      status: "approved", reason: "" }
    expect(response).to have_http_status(:unprocessable_content)
    post admin_review_figure_claim_path("practice", claim), params: { review_action: "withdraw", revision: claim.moderation_revision,
      status: "approved", reason: "The video was retracted." }
    expect(claim.reload).to be_hidden
    get admin_figure_claim_path("practice", claim)
    expect(response.body).to include("The video was retracted.", "Trusted admin publication")
  end

  it "removing the only attestation unpublishes the claim and blocks republishing" do
    sign_in admin
    claim = create_walk_claim
    add_video(claim)
    publish claim
    delete admin_claim_attestation_path("practice", claim, claim.attestations.sole)
    expect(claim.reload).to be_pending
    publish claim
    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Add at least one Attestation")
  end

  it "creates business ties and statements, resolving Figures by code" do
    sign_in admin
    post admin_create_claim_identity_path("business"), params: { record: { name: "Harbor Coffee", founded_year: "2019" } }
    business = Business.find_by!(entity_code: "BUSINESS-HARBOR_COFFEE")
    post admin_create_figure_claim_path("business"), params: { claim: { entity_code: "BUSINESS_TIE-REYES-HARBOR",
      figure_code: figure.entity_code, business_id: business.id, predicate: "invests_in", vehicle_name: "Reyes Holdings",
      compensation: "unknown", temporal_state: "unknown" } }
    expect(FigureBusinessRelationship.sole).to have_attributes(figure: figure, vehicle_name: "Reyes Holdings")
    post admin_create_figure_claim_path("statement"), params: { claim: { entity_code: "STATEMENT-REYES-1",
      figure_code: figure.entity_code, attribution_kind: "observer_characterization", text: "The hardest worker I've coached.",
      observer_name: "A former coach" } }
    expect(AttributedStatement.sole.observer_name).to eq("A former coach")
    post admin_create_figure_claim_path("statement"), params: { claim: { entity_code: "STATEMENT-REYES-2",
      figure_code: "FIGURE-NOBODY", attribution_kind: "direct_quote", text: "x" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("No Figure has the code FIGURE-NOBODY")
  end
end
