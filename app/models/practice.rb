# A broad activity or meaning, such as meditation, prayer or gratitude. Which
# Protocols a Practice describes is attributed per Figure, never global.
class Practice < ApplicationRecord
  has_many :practice_connections, dependent: :restrict_with_error
  has_many :figure_practice_relationships, through: :practice_connections

  validates :name, :entity_code, presence: true
  validates :entity_code, uniqueness: true
end
