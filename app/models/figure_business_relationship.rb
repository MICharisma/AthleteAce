# One sourced commercial tie between a Figure and a Business. Each predicate is
# its own row with its own dates and evidence, so a sponsorship never implies a
# promotion, ownership or investment.
class FigureBusinessRelationship < ApplicationRecord
  include TemporalClaim
  include Attested
  include ReviewedClaim

  PREDICATES = %w[founded owns invests_in endorses promotes sponsored_by].freeze
  COMPENSATIONS = %w[documented_paid documented_unpaid unknown].freeze
  COMPENSATED_PREDICATES = %w[endorses promotes sponsored_by].freeze

  belongs_to :figure
  belongs_to :business

  enum :predicate, PREDICATES.index_with(&:itself), validate: true
  # Absent a payment disclosure, compensation is unknown, never unpaid.
  enum :compensation, COMPENSATIONS.index_with(&:itself), prefix: true, validate: true

  validate :predicate_fits_details

  private

  def review_targets
    { "business" => identity(business, "url", "founded_year") }
  end

  def predicate_fits_details
    # Founding is an event: it stays true after the founder exits.
    errors.add :end_date, "must be absent for a founding event" if founded? && end_date.present?
    errors.add :temporal_state, "cannot be reported current for a founding event" if founded? && reported_current?
    unless predicate.in?(COMPENSATED_PREDICATES)
      errors.add :compensation, "applies only to endorsements, promotions and sponsorships" unless compensation_unknown?
      errors.add :compensation_description, "applies only to endorsements, promotions and sponsorships" if compensation_description.present?
    end
    # An investment through a fund or holding vehicle names that vehicle.
    errors.add :vehicle_name, "applies only to investments" if vehicle_name.present? && !invests_in?
  end
end
