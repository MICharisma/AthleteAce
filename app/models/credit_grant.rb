class CreditGrant < ApplicationRecord
  belongs_to :ace
  belongs_to :actor, class_name: "Ace"

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, presence: true, length: { maximum: 2000 }

  def self.issue!(ace:, actor:, amount_cents:, reason:, request_key:)
    unless request_key.to_s.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i)
      raise ArgumentError, "Reload the page before granting credit."
    end

    actor.with_lock(requires_new: true) do
      unless actor.admin? && actor.active_for_authentication?
        raise Moderation::Review::Forbidden, "Only active admins can grant credit."
      end

      attributes = { ace_id: ace.id, actor_id: actor.id, amount_cents: amount_cents, reason: reason.to_s.strip }
      grant = create_or_find_by!(id: request_key) { |record| record.assign_attributes(attributes) }
      unless attributes.all? { |attribute, value| grant[attribute] == value }
        raise Moderation::Review::Conflict, "This grant was already recorded with different details. Reload before trying again."
      end

      CreditAccount.for(ace).apply!(source: grant, kind: "grant", available_delta: amount_cents)
      grant
    end
  end

  def readonly?
    persisted?
  end
end
