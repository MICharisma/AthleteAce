# One Practice named within a Figure's practice relationship.
class PracticeConnection < ApplicationRecord
  belongs_to :figure_practice_relationship
  belongs_to :practice

  validates :entity_code, presence: true, uniqueness: true
  validates :practice_id, uniqueness: { scope: :figure_practice_relationship_id }

  # The Practice set is part of the reviewed claim.
  after_create { figure_practice_relationship.note_material_change! "#{practice.name} added" }
  after_update { figure_practice_relationship.note_material_change! "#{practice.name} changed" if (saved_changes.keys - %w[updated_at]).any? }
  after_destroy { figure_practice_relationship.note_material_change! "#{practice.name} removed" }
end
