# A Figure's sourced connection to a Protocol and/or Practices: doing,
# recommending, teaching or endorsing it. The Practices named here are this
# Figure's interpretation in this source, not a classification of the Protocol.
class FigurePracticeRelationship < ApplicationRecord
  include TemporalClaim
  include Attested

  PREDICATES = %w[participates_in recommends teaches endorses].freeze

  belongs_to :figure
  belongs_to :protocol, optional: true
  has_many :practice_connections, dependent: :delete_all
  has_many :practices, -> { order(:name, :entity_code) }, through: :practice_connections
  has_many :attributed_statements, dependent: :restrict_with_error

  enum :predicate, PREDICATES.index_with(&:itself), validate: true

  # A claim needs a Protocol or at least one Practice before it can publish.
  def targeted?
    protocol_id.present? || practice_connections.exists?
  end
end
