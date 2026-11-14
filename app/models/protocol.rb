# A concrete method or routine, such as a morning walk. It has no fixed parent
# Practice; each Figure's sourced relationship names the Practices it means.
class Protocol < ApplicationRecord
  has_many :figure_practice_relationships, dependent: :restrict_with_error

  validates :name, :entity_code, presence: true
  validates :entity_code, uniqueness: true

  # A materially different method belongs in a new Protocol. If one is edited
  # anyway, every claim naming it returns to review.
  after_update do
    if saved_change_to_name? || saved_change_to_description? || saved_change_to_routine?
      figure_practice_relationships.find_each { it.note_material_change! "#{entity_code} method changed" }
    end
  end
end
