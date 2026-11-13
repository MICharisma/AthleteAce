class Membership < ApplicationRecord
  belongs_to :team
  belongs_to :league
  belongs_to :conference, optional: true
  belongs_to :division, optional: true
  
  has_one :sport, through: :league

  before_validation :assign_hierarchy
  validate :hierarchy_matches_league
  
  scope :active, -> { where(active: true) }
  
  # Allow all attributes to be searchable with Ransack
  def self.ransackable_attributes auth_object = nil
    column_names
  end
  
  # Allow all associations to be searchable with Ransack
  def self.ransackable_associations auth_object = nil
    reflect_on_all_associations.map { |a| a.name.to_s }
  end

  private

  def assign_hierarchy
    self.conference ||= division&.conference
    self.league ||= division&.league || conference&.league || team&.league
  end

  def hierarchy_matches_league
    if conference && league && conference.league_id != league.id
      errors.add :conference, "must belong to the membership's league"
    end
    if division && league && division.league_id != league.id
      errors.add :division, "must belong to the membership's league"
    end
    if division && division.conference != conference
      errors.add :division, "must belong to the membership's conference"
    end
    if active? && team && league && team.league_id != league.id
      errors.add :league, "must match the team's current league for an active membership"
    end
  end
end
