class Follow < Engagements::Engagement
  default_scope { where(actor_type: "Ace", kind: "follow") }

  alias_attribute :ace_id, :actor_id
  alias_attribute :followable_type, :engageable_type
  alias_attribute :followable_id, :engageable_id

  belongs_to :ace, foreign_key: :actor_id, inverse_of: :follows
  belongs_to :followable, polymorphic: true, foreign_key: :engageable_id, foreign_type: :engageable_type

  validates :followable_type, inclusion: { in: %w[Team Player] }
end
