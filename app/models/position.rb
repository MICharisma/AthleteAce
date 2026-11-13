class Position < ApplicationRecord
  KINDS = %w[position apparatus event weapon].freeze

  belongs_to :sport
  belongs_to :parent, class_name: "Position", optional: true
  has_many :children, class_name: "Position", foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify
  has_many :position_assignments, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :sport_id, message: "already exists for this sport" }
  validates :kind, inclusion: { in: KINDS }
  validate :parent_in_same_sport

  def to_s
    name
  end

  # Define which attributes can be searched via Ransack
  def self.ransackable_attributes(auth_object = nil)
    [ "abbreviation", "created_at", "description", "id", "kind", "name", "parent_id", "sport_id", "updated_at" ]
  end

  # Define which associations can be searched via Ransack
  def self.ransackable_associations(auth_object = nil)
    [ "children", "parent", "position_assignments", "sport" ]
  end

  private

  # Groups may nest (Offense > OL > LT) but never loop back to the position.
  def parent_in_same_sport
    return unless parent
    errors.add :parent, "must belong to the same sport" unless parent.sport_id == sport_id
    ancestor = parent
    seen = []
    while ancestor
      if (id && ancestor.id == id) || seen.include?(ancestor.id)
        errors.add :parent, "cannot loop back to the position"
        break
      end
      seen << ancestor.id
      ancestor = ancestor.parent
    end
  end
end
