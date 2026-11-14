# One Practice named within a Figure's practice relationship.
class PracticeConnection < ApplicationRecord
  belongs_to :figure_practice_relationship
  belongs_to :practice

  validates :entity_code, presence: true, uniqueness: true
  validates :practice_id, uniqueness: { scope: :figure_practice_relationship_id }
end
