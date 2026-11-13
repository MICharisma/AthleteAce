class Division < ApplicationRecord
  include Ratable
  
  belongs_to :league
  belongs_to :conference, optional: true
  has_many :memberships, dependent: :destroy
  has_many :active_memberships, -> { active }, class_name: "Membership"
  has_many :teams, -> { distinct }, through: :active_memberships
  has_many :campaigns, through: :teams
  has_many :contestants, through: :campaigns
  has_many :contests, through: :contestants
  has_many :contracts, through: :teams
  has_many :activations, through: :contracts
  
  validates :name, presence: true
  before_validation :assign_league
  validate :conference_matches_league
  
  def display_name
    if abbreviation.present?
      "#{name} (#{abbreviation})"
    else
      name
    end
  end
  
  
  def self.ransackable_attributes auth_object = nil
    column_names
  end
  
  def self.ransackable_associations auth_object = nil
    reflect_on_all_associations.map { |a| a.name.to_s }
  end

  private

  def assign_league
    self.league ||= conference&.league
  end

  def conference_matches_league
    if conference && league && conference.league_id != league.id
      errors.add :conference, "must belong to the division's league"
    end
  end
end
