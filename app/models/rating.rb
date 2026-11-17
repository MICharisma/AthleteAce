class Rating < ApplicationRecord
  SCALE = SharedRatings::Scales.standard(
    key: "athleteace.rating", version: 2, question: "How do you rate this entity?",
    low_label: "Low", high_label: "High"
  )
  HIGH_AFFINITY_THRESHOLD = 250

  belongs_to :ace
  belongs_to :spectrum
  belongs_to :target, polymorphic: true

  after_create :record_revision
  after_update :record_revision, if: -> { saved_changes.keys.intersect? %w[value notes archived spectrum_id target_type target_id] }
  before_destroy { RatingRevision.record! reload, operation: "remove" }
  
  # Validations
  validates :value, presence: true, 
                   numericality: { 
                     only_integer: true, 
                     greater_than_or_equal_to: SCALE.minimum,
                     less_than_or_equal_to: SCALE.maximum
                   }
  
  # Scopes
  scope :by_ace, ->(ace) { where(ace: ace) }
  scope :by_spectrum, ->(spectrum) { where(spectrum: spectrum) }
  scope :for_target, ->(target) { where(target: target) }
  scope :positive, -> { where('value > 0') }
  scope :negative, -> { where('value < 0') }
  scope :neutral, -> { where(value: 0) }
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }
  
  # Methods
  def positive?
    value > 0
  end
  
  def negative?
    value < 0
  end
  
  def neutral?
    value == 0
  end
  
  # Normalized value between 0 and 1 for display purposes
  def normalized_value
    SCALE.position value
  end
  
  # Percentage value (0-100) for display purposes
  def percentage_value
    (normalized_value * 100).round
  end

  private

  def record_revision
    RatingRevision.record! self, operation: archived? ? "archive" : "set"
  end
end
