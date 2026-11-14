module FigureClaims
  # Trusted admin publication for phase one: an active admin publishes the
  # exact revision they previewed, or rejects, withdraws or reopens a claim.
  # Community submissions (AA-219) will need a second reviewer.
  class Review
    class Conflict < StandardError; end
    class Forbidden < StandardError; end

    TRANSITIONS = {
      "publish" => [ %w[pending], "approved", "approved" ],
      "reject" => [ %w[pending], "rejected", "rejected" ],
      "withdraw" => [ %w[approved], "hidden", "hidden" ],
      "reopen" => [ %w[rejected hidden], "pending", "reopened" ]
    }.freeze

    def self.call(claim:, actor:, action:, revision:, status:, digest: nil, reason: nil)
      raise Forbidden, "Only an active admin can review Figure claims." unless actor&.admin? && !actor.suspended?
      allowed, destination, decision = TRANSITIONS.fetch(action) { raise ArgumentError, "Unknown review action." }
      raise ArgumentError, "Give a reason for this decision." if %w[reject withdraw].include?(action) && reason.blank?
      raise ArgumentError, "The reason is too long." if reason.to_s.length > 2000

      claim.with_lock do
        if claim.moderation_revision != revision.to_i || claim.moderation_status != status
          raise Conflict, "This claim changed or was already decided. Reload before reviewing."
        end
        raise Conflict, "This action does not apply to the current status." unless allowed.include?(claim.moderation_status)
        if action == "publish"
          raise Conflict, "The claim or its evidence changed since your preview. Reload before publishing." if digest != claim.review_digest
          problems = claim.publication_problems
          raise Conflict, problems.to_sentence if problems.any?
        end
        previous = claim.moderation_status
        claim.update_columns moderation_status: destination, updated_at: Time.current
        claim.moderation_decisions.create! actor: actor, action: decision, from_status: previous, to_status: destination,
          revision: claim.moderation_revision, reason: reason.presence || (action == "publish" ? "Trusted admin publication" : nil),
          snapshot: claim.review_snapshot
      end
      claim
    end
  end
end
