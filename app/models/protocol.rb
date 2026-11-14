# A concrete method or routine, such as a morning walk. It has no fixed parent
# Practice; each Figure's sourced relationship names the Practices it means.
class Protocol < ApplicationRecord
  has_many :figure_practice_relationships, dependent: :restrict_with_error

  validates :name, :entity_code, presence: true
  validates :entity_code, uniqueness: true
end
