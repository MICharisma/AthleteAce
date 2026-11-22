class Team < ApplicationRecord
  include HasLogos
  has_many :staff_tenures, dependent: :restrict_with_error
  has_many :shout_outs, as: :target, dependent: :nullify
  has_many :shout_out_drafts, as: :target, dependent: :nullify
  has_many :follows, as: :followable, dependent: :destroy
  include Ratable
  before_validation :assign_palette_text_color
  
  belongs_to :league
  belongs_to :stadium, optional: true
  has_many :players
  has_many :jersey_number_assignments, dependent: :destroy
  has_many :uniforms, dependent: :destroy
  has_many :contracts, dependent: :nullify
  has_many :contract_players, through: :contracts, source: :player
  has_many :stints, dependent: :restrict_with_error
  has_many :rosters, through: :campaigns
  has_many :appearances, through: :contestants
  has_many :organization_affiliations, dependent: :destroy
  has_many :organizations, through: :organization_affiliations
  has_one :current_organization_affiliation, -> { current.order(start_date: :desc, created_at: :desc) }, class_name: "OrganizationAffiliation"
  has_one :current_organization, through: :current_organization_affiliation, source: :organization
  has_many :memberships, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :title_awards, through: :campaigns
  has_one :active_membership, -> { where(active: true) }, class_name: 'Membership'
  has_one :division, through: :active_membership
  has_one :conference, through: :active_membership
  has_many :contestants, through: :campaigns
  has_many :contests, through: :contestants
  has_many :activations, through: :campaigns
  has_many :team_namings, dependent: :destroy
  has_many :nicknames, -> { distinct }, through: :team_namings
  has_many :tenancies, dependent: :destroy

  delegate :sport, to: :league
  delegate :city, :state, :country, to: :stadium, allow_nil: true

  scope :matching_name, ->(query) {
    where("CONCAT_WS(' ', teams.territory, teams.mascot, teams.abbreviation) ILIKE ?", "%#{sanitize_sql_like(query)}%")
  }

  def name
    [ territory, mascot ].compact_blank.join(" ")
  end
  alias :full_name :name

  # The territory, mascot, abbreviation and stadium columns cache the current
  # values. A name falls back to that cache, since it still identifies the
  # franchise; a stadium does not, since today's venue would misstate history.
  def name_on(date)
    (date && team_namings.in_force_on(date).first&.name.presence) || name
  end

  def stadium_on(date)
    tenancies.home.in_force_on(date).first&.stadium if date
  end

  
  # Define which attributes can be searched via Ransack
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "league_id", "mascot", "stadium_id", "territory", "updated_at"]
  end
  
  # Define which associations can be searched via Ransack
  def self.ransackable_associations(auth_object = nil)
    ["active_membership", "campaigns", "conference", "current_organization", "current_organization_affiliation", "division", "league", "memberships", "organization_affiliations", "organizations", "players", "ratings", "stadium"]
  end

  private

  def assign_palette_text_color
    if will_save_change_to_primary_color? || text_color.blank?
      self.text_color = TeamPalette.text_color(primary_color)
    end
  end
end
