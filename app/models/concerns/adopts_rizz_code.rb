# Lets a record take a Rizz code (MIC-RZZ-..., a figure's person code or a
# place's code such as MIC-RZZ-LOC-US-NY-NEW_YORK) as its canonical
# entity_code. The provisional code and every earlier alias stay bound to the
# record, so seed files, UGC exports and links that use them keep resolving.
module AdoptsRizzCode
  extend ActiveSupport::Concern

  RIZZ_NAMESPACE = "MIC".freeze
  RIZZ_CATALOG = "RZZ".freeze
  RIZZ_PREFIX = "#{RIZZ_NAMESPACE}-#{RIZZ_CATALOG}-".freeze

  def rizz_code?
    entity_code.to_s.start_with?(RIZZ_PREFIX)
  end

  def adopt_rizz_code!(qualified_code)
    raise ArgumentError, "#{qualified_code.inspect} is not a Rizz code" unless qualified_code.to_s.start_with?(RIZZ_PREFIX)
    return false if entity_code == qualified_code

    transaction do
      lock!
      previous = entity_code
      EntityCode.where(record_type: self.class.polymorphic_name, record_id: id).update_all(canonical_code: qualified_code, updated_at: Time.current)
      if previous.present?
        alias_binding = EntityCode.find_or_initialize_by(namespace: RIZZ_NAMESPACE, catalog: "ALA", code: previous)
        alias_binding.update!(canonical_code: qualified_code, record: self)
      end
      EntityCode.find_or_initialize_by(namespace: RIZZ_NAMESPACE, catalog: RIZZ_CATALOG, code: qualified_code.delete_prefix(RIZZ_PREFIX))
        .update!(canonical_code: qualified_code, record: self)
      update!(entity_code: qualified_code)
    end
    true
  end
end
