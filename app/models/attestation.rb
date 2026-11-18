# Text, a link, an image or a video that supports one claim. The claim's
# Figure, the material's original author, its publisher and the Ace who entered
# it are kept apart; an Attestation is attributed evidence, not a verdict.
class Attestation < ApplicationRecord
  include PartialDates

  CONTENT_FORMS = %w[text link image video].freeze
  CLAIM_TYPES = %w[FigureBusinessRelationship FigurePracticeRelationship AttributedStatement].freeze

  belongs_to :claim, polymorphic: true
  belongs_to :author, class_name: "Figure", optional: true
  belongs_to :entered_by, class_name: "Ace", optional: true

  partial_dates :published_on
  enum :content_form, CONTENT_FORMS.index_with(&:itself), validate: true

  validates :claim_type, inclusion: { in: CLAIM_TYPES }
  validates :entity_code, presence: true, uniqueness: true
  validates :url, :media_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be an http(s) URL" }, allow_blank: true
  validate :payload_is_present

  # Evidence changes send the claim back to review.
  after_create { claim.note_material_change! "#{entity_code} added" }
  after_update :note_changed_evidence
  after_destroy { claim.note_material_change! "#{entity_code} removed" }

  scope :published, -> {
    where(CLAIM_TYPES.map { |type| "(attestations.claim_type = '#{type}' AND attestations.claim_id IN (#{type.constantize.published.select(:id).to_sql}))" }.join(" OR "))
  }

  # Enough to assess support: a traceable source and the context it supports.
  def complete?
    valid? && (url.present? || media_url.present? || source_title.present?) && context.present?
  end

  def review_snapshot
    attributes.except("id", "claim_type", "claim_id", "author_id", "entered_by_id", "created_at", "updated_at")
      .merge("author" => author && { "entity_code" => author.entity_code, "name" => author.name }, "entered_by_id" => entered_by_id)
  end

  private

  def note_changed_evidence
    return if (saved_changes.keys - %w[updated_at]).empty?

    if saved_change_to_claim_id? || saved_change_to_claim_type?
      previous = claim_type_before_last_save.constantize.find_by(id: claim_id_before_last_save)
      previous&.note_material_change! "#{entity_code} moved to another claim"
    end
    claim.note_material_change! "#{entity_code} changed"
  end

  def payload_is_present
    case content_form
    when "text" then errors.add :body, "is required for a text attestation" if body.blank?
    when "link" then errors.add :url, "is required for a link attestation" if url.blank?
    when "image", "video"
      errors.add :media_url, "or url is required for #{content_form} attestations" if media_url.blank? && url.blank?
    end
  end
end
