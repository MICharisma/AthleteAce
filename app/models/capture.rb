class Capture < ApplicationRecord
  belongs_to :player
  belongs_to :shot

  validates :player_id, uniqueness: { scope: :shot_id }
  validates :weight, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
