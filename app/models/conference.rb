class Conference < ApplicationRecord
  belongs_to :league
  has_many :divisions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :active_memberships, -> { active }, class_name: "Membership"
  has_many :teams, -> { distinct }, through: :active_memberships
  has_many :players, through: :teams
  has_many :campaigns, through: :teams
  has_many :contests, through: :campaigns
  has_many :contracts, through: :teams
  
  validates :name, presence: true
  validates :abbreviation, presence: true
  
  def display_name
    "#{name} (#{abbreviation})"
  end
  
  # Allow all attributes to be searchable with Ransack
  def self.ransackable_attributes(auth_object = nil)
    column_names
  end
  
  # Allow all associations to be searchable with Ransack
  def self.ransackable_associations(auth_object = nil)
    reflect_on_all_associations.map { |a| a.name.to_s }
  end
end
