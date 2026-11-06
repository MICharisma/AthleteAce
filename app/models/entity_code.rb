class EntityCode < ApplicationRecord
  belongs_to :record, polymorphic: true, optional: true

  validates :namespace, :catalog, :code, :canonical_code, presence: true
  validates :code, uniqueness: { scope: [:namespace, :catalog] }

  def record
    return if canonical_code.blank? || record_type.blank? || record_id.nil?

    record_class = association(:record).klass
    return unless record_class.column_names.include?("entity_code")

    record_class.find_by id: record_id, entity_code: canonical_code
  end
  alias_method :resolved_record, :record

  # Finds the record a code or one of its aliases names, or nil when the code
  # names a different kind of record.
  def self.resolve(model, code, namespace: "MIC", catalog: "ALA")
    binding = find_by(namespace: namespace, catalog: catalog, code: code)
    if binding
      return unless binding.record_type == model.polymorphic_name

      target = binding.resolved_record || model.find_by(entity_code: binding.canonical_code)
      return target if target
    end
    model.find_by(entity_code: code)
  end
end
