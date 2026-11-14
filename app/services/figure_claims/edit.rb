module FigureClaims
  # Saves an admin's claim form, and a practice relationship's whole Practice
  # set, atomically. The revision guard stops a stale form from overwriting a
  # newer revision.
  class Edit
    class Conflict < StandardError; end

    def self.call(claim:, attributes:, revision: nil, practice_ids: nil)
      claim.transaction do
        if claim.persisted?
          claim.lock!
          raise Conflict, "This claim changed since you opened it. Reload before saving." if claim.moderation_revision != revision.to_i
        end
        claim.assign_attributes attributes
        claim.save!
        sync_practices(claim, practice_ids) if practice_ids
      end
      claim
    end

    def self.sync_practices(claim, practice_ids)
      wanted = Practice.where(id: practice_ids.compact_blank.uniq).to_a
      claim.practice_connections.where.not(practice_id: wanted.map(&:id)).destroy_all
      present = claim.practice_connections.pluck(:practice_id)
      wanted.reject { present.include?(it.id) }.each do |practice|
        claim.practice_connections.create! practice: practice, entity_code: "#{claim.entity_code}-#{practice.entity_code}"
      end
    end
  end
end
