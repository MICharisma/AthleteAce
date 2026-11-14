# A sourced relationship with a date range and a reported state. A missing end
# date never implies current: only reported_current with an as-of date does.
module TemporalClaim
  extend ActiveSupport::Concern
  include PartialDates

  STATES = %w[reported_current historical planned unknown].freeze

  included do
    partial_dates :start_date, :end_date, range: %i[start_date end_date]
    partial_dates :as_of_date

    enum :temporal_state, STATES.index_with(&:itself), validate: true
    validates :entity_code, presence: true, uniqueness: true
    validate :temporal_state_is_supported
  end

  private

  def temporal_state_is_supported
    if reported_current?
      errors.add :as_of_date, "is required for a reported current relationship" if as_of_date.blank?
      errors.add :end_date, "must be absent for a reported current relationship" if end_date.present?
    end
    errors.add :end_date, "must be absent for a planned relationship" if planned? && end_date.present?
  end
end
