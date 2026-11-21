# Links one Ace to one Rizz subject. rizz_session_epoch only moves forward; a
# Rizz-opened session older than it (or any session once disconnected) is ended.
class AceRizzBinding < ApplicationRecord
  STATUSES = %w[active disconnected].freeze

  belongs_to :ace

  validates :rizz_sub, :operation_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end
end
