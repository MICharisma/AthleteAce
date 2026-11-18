# An editor-managed label that organizes attributed statements. A Topic never
# establishes a belief or value on its own.
class Topic < ApplicationRecord
  has_many :attributed_statements, dependent: :restrict_with_error

  validates :name, :entity_code, presence: true
  validates :name, :entity_code, uniqueness: true
end
