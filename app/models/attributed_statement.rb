# Something a Figure said, or something an observer said about them. The kind
# keeps quotes, paraphrases, self-stated values and characterizations apart.
class AttributedStatement < ApplicationRecord
  include PartialDates
  include Attested

  KINDS = %w[direct_quote attributed_paraphrase self_stated_value observer_characterization].freeze

  belongs_to :figure
  belongs_to :topic, optional: true
  belongs_to :figure_practice_relationship, optional: true
  belongs_to :staff_tenure, optional: true
  belongs_to :observer, class_name: "Figure", optional: true

  partial_dates :statement_date
  enum :attribution_kind, KINDS.index_with(&:itself), validate: true

  validates :text, :entity_code, presence: true
  validates :entity_code, uniqueness: true
  validate :attribution_is_consistent

  private

  def attribution_is_consistent
    if observer_characterization?
      errors.add :observer, "or observer name is required for an observer characterization" if observer.nil? && observer_name.blank?
      errors.add :observer, "must not be the Figure described" if observer_id.present? && observer_id == figure_id
    elsif observer.present? || observer_name.present?
      errors.add :observer, "applies only to observer characterizations"
    end
    if figure_practice_relationship && figure_practice_relationship.figure_id != figure_id
      errors.add :figure_practice_relationship, "must concern the same Figure"
    end
    errors.add :staff_tenure, "must belong to the same Figure" if staff_tenure && staff_tenure.figure_id != figure_id
  end
end
