# A Figure claim that is public only while an admin's approval covers its
# current revision. Any material change, to the claim, its Practice set, its
# Attestations or its Protocol's method, increments the revision and returns
# it to pending, whichever path made the change (admin, console or import).
module ReviewedClaim
  extend ActiveSupport::Concern

  STATUSES = %w[pending approved rejected hidden].freeze
  REVIEW_COLUMNS = %w[moderation_status moderation_revision revision_transaction updated_at].freeze

  included do
    has_many :moderation_decisions, -> { order(:created_at, :id) }, as: :subject

    validates :moderation_status, inclusion: { in: STATUSES }
    scope :published, -> { where(moderation_status: "approved") }
    scope :with_status, ->(status) { where(moderation_status: status) }

    before_create { self.revision_transaction = self.class.current_transaction.uuid }
    before_update :note_own_material_change
    after_update :record_own_material_change
  end

  # Called when a dependent record changes. Several changes in one transaction
  # count as one revision.
  def note_material_change!(description)
    return if new_record? || destroyed?

    transaction = self.class.current_transaction
    with_lock do
      next if transaction.open? && revision_transaction == transaction.uuid

      previous = moderation_status
      update_columns moderation_revision: moderation_revision + 1, moderation_status: "pending",
        revision_transaction: transaction.uuid, updated_at: Time.current
      record_change previous, description
    end
  end

  # Everything a reviewer approves: the claim, its targets and its exact
  # evidence. Stored with each decision and digested to detect stale review.
  def review_snapshot
    {
      "type" => self.class.name, "id" => id, "entity_code" => entity_code, "revision" => moderation_revision,
      "figure" => identity(figure), "attributes" => material_attributes, "targets" => review_targets,
      "attestations" => attestations.reload.map(&:review_snapshot)
    }
  end

  def review_digest
    Digest::SHA256.hexdigest JSON.generate(review_snapshot.except("revision"))
  end

  # Reasons the current revision cannot be published, if any.
  def publication_problems
    problems = []
    problems << "The claim is invalid: #{errors.full_messages.to_sentence}" unless valid?
    problems.concat target_problems
    evidence = attestations.reload
    problems << "Add at least one Attestation." if evidence.empty?
    evidence.reject(&:complete?).each do |attestation|
      problems << "#{attestation.entity_code} needs a traceable source and context explaining what it supports."
    end
    problems
  end

  STATUSES.each do |status|
    define_method(:"#{status}?") { moderation_status == status }
  end
  alias_method :published?, :approved?

  private

  def target_problems
    []
  end

  def identity(record, *extra)
    return unless record

    { "entity_code" => record.entity_code, "name" => record.try(:name) }.merge(record.attributes.slice(*extra))
  end

  def material_attributes
    foreign_keys = self.class.reflect_on_all_associations(:belongs_to).map(&:foreign_key)
    attributes.except("id", "created_at", *REVIEW_COLUMNS, *foreign_keys)
  end

  def note_own_material_change
    return if (changed_attribute_names_to_save - REVIEW_COLUMNS).empty?

    transaction = self.class.current_transaction
    return if transaction.open? && revision_transaction == transaction.uuid

    @changed_from_status = moderation_status
    self.moderation_revision += 1
    self.moderation_status = "pending"
    self.revision_transaction = transaction.uuid
  end

  def record_own_material_change
    return unless @changed_from_status

    previous, @changed_from_status = @changed_from_status, nil
    record_change previous, "claim fields"
  end

  # A pending claim stays pending; only a decided claim's return is a transition.
  def record_change(previous, description)
    return if previous == "pending"

    moderation_decisions.create! action: "submitted", from_status: previous, to_status: "pending",
      revision: moderation_revision, reason: "Content changed: #{description}",
      snapshot: { "type" => self.class.name, "id" => id, "entity_code" => entity_code }
  end
end
