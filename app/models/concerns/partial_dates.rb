# Dates stored as text at the source's precision: YYYY, YYYY-MM or YYYY-MM-DD,
# with nil meaning unknown. `partial_dates :start_date, :end_date` validates
# each value and rejects a range whose start lies entirely after its end.
module PartialDates
  extend ActiveSupport::Concern

  FORMAT = /\A[0-9]{4}(?:-[0-9]{2}(?:-[0-9]{2})?)?\z/

  # The first and last calendar days a partial date can mean, or nil.
  def self.bounds(value)
    return unless value&.match?(FORMAT)

    year, month, day = value.split("-").map(&:to_i)
    return unless year.positive?

    first = Date.new(year, month || 1, day || 1)
    last = day ? first : month ? first.end_of_month : first.end_of_year
    [ first, last ]
  rescue Date::Error
    nil
  end

  class_methods do
    def partial_dates(*attributes, range: nil)
      normalizes(*attributes, with: ->(value) { value.presence })
      validate do
        attributes.each do |attribute|
          value = public_send(attribute)
          errors.add(attribute, "must be YYYY, YYYY-MM, or YYYY-MM-DD") if value.present? && PartialDates.bounds(value).nil?
        end
        if range
          first, last = range.map { PartialDates.bounds(public_send(it)) }
          errors.add range.last, "must not be before the #{range.first.to_s.humanize(capitalize: false)}" if first && last && first.first > last.last
        end
      end
    end
  end
end
