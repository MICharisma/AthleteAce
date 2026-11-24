require "rails_helper"

# Where each table's records go in `rails ugc:full_reseed`. The reset deletes
# CORE_MODELS and reseeds them with new ids, clears and restores the backed-up
# UGC that points at them, and leaves every other table as it is. A new model
# fails the inventory example until it is placed here or in the service.
RSpec.describe UgcResetService do
  # Tables the reset leaves as they are, grouped by what they hold.
  KEPT = {
    accounts: %w[AccountAction AceRizzBinding SignInEvent RizzBackchannelLogoutEvent RizzClaimHandoff RizzClaimReceipt RizzFeedCursor RizzName RizzSync],
    credits: %w[CreditAccount CreditEntry StripePurchase],
    posts_and_moderation: %w[Follow Mute ShoutOut ShoutOutDraft ShoutOutReaction ShoutOutReport ModerationDecision ModerationEscalation ModeratorNote PostingWarning DecisionEvaluation PracticeReview RatingRevision],
    play: %w[GameRound GoalAchievement],
    catalog_outside_the_reset: %w[CatalogEdit EntityCode Nickname TeamNaming Tenancy Shot ShotUploadToken Capture]
  }.freeze

  # Kept records that can name a catalog row by id. After a reset they point
  # at rows that no longer exist. Move a model into CORE_MODELS, or back it up
  # and restore it by identifier, then take it off this list.
  KEPT_POINTING_AT_CATALOG = %w[
    Capture CreditEntry DecisionEvaluation EntityCode Follow ModerationDecision ModerationEscalation
    PostingWarning RizzName RizzSync ShoutOut ShoutOutDraft TeamNaming Tenancy
  ].freeze

  def models
    Rails.application.eager_load!
    ApplicationRecord.descendants.reject(&:abstract_class?).map(&:base_class).uniq
  end

  def points_at_catalog?(model)
    model.reflect_on_all_associations(:belongs_to).any? { |association| association.polymorphic? || described_class::CORE_MODELS.include?(association.klass) }
  end

  it "places every model" do
    unplaced = models.map(&:name) - described_class::CORE_MODELS.map(&:name) - described_class::UGC_MODELS.map(&:name) - KEPT.values.flatten
    expect(unplaced).to be_empty, "Place these models in UgcResetService or in KEPT in #{__FILE__}: #{unplaced.join(', ')}"
  end

  it "places each model once" do
    placements = described_class::CORE_MODELS.map(&:name) + described_class::UGC_MODELS.map(&:name) + KEPT.values.flatten
    expect(placements.tally.select { |_, count| count > 1 }.keys).to be_empty
  end

  it "clears and restores every backed-up model that points at catalog rows" do
    expect(described_class::UGC_MODELS.select { points_at_catalog? it }).to all(be_in(described_class::DEPENDENT_UGC_MODELS))
  end

  it "keeps the listed models that point at catalog rows, and no others" do
    kept = models.select { KEPT.values.flatten.include?(it.name) }
    expect(kept.select { points_at_catalog? it }.map(&:name)).to match_array(KEPT_POINTING_AT_CATALOG)
  end
end
