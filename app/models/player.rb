class Player < ApplicationRecord
  NAME_ATTRIBUTES = %w[first_name last_name nicknames].freeze

  default_scope { preload :figure }
  belongs_to :figure, autosave: true, inverse_of: :players
  before_validation :attach_figure_identity, on: :create
  has_many :shout_outs, as: :target, dependent: :nullify
  has_many :shout_out_drafts, as: :target, dependent: :nullify
  has_many :follows, as: :followable, dependent: :destroy
  include Ratable
  
  belongs_to :birth_city, class_name: 'City', optional: true
  belongs_to :birth_country, class_name: 'Country', optional: true
  belongs_to :team, optional: true
  belongs_to :sport, optional: true
  delegate :league, to: :team, allow_nil: true
  delegate :current_organization, to: :team, allow_nil: true
  
  has_many :player_group_memberships, dependent: :destroy
  has_many :player_groups, through: :player_group_memberships
  has_many :roles, dependent: :destroy
  has_many :jersey_number_assignments, dependent: :destroy
  has_many :positions, through: :roles
  has_many :contracts, dependent: :destroy
  has_many :contract_teams, through: :contracts, source: :team
  has_many :contract_organizations, -> { distinct }, through: :contracts, source: :organization
  has_many :stints, dependent: :destroy
  has_many :roster_entries, dependent: :destroy
  has_many :appearances, dependent: :destroy
  has_many :transaction_players, dependent: :destroy
  has_many :activations, dependent: :destroy
  has_many :campaigns, -> { distinct }, through: :activations
  
  # Ransack configuration
  # Define searchable attributes and associations
  # Allow searching and sorting by team name
  ransacker :team_name do
    Arel.sql("teams.mascot")
  end
  
  # Allow searching and sorting by team territory
  ransacker :team_territory do
    Arel.sql("teams.territory")
  end
  
  # Allow searching and sorting by league name
  ransacker :league_name do
    Arel.sql("leagues.name")
  end
  
  # Allow searching and sorting by sport name
  ransacker :sport_name do
    Arel.sql("sports.name")
  end
  
  # Allow searching and sorting by position name
  ransacker :position_name do
    Arel.sql("positions.name")
  end
  
  def self.ransackable_attributes(auth_object = nil)
    ["active", "bio", "birth_city_id", "birth_country_id", "birthdate", "created_at", "current_position", "debut_year", "draft_year", "id", "league_name", "photo_urls", "position_name", "sport_name", "team_id", "team_name", "team_territory", "updated_at"]
  end
  
  def self.ransackable_associations(auth_object = nil)
    ["birth_city", "birth_country", "positions", "ratings", "roles", "sport", "team"]
  end
  
  scope :sampled, ->(n = 50) { order(Arel.sql('RANDOM()')).limit(n) }
  scope :by_name, -> { joins(:figure).merge(Figure.order(:sort_name)).order(:id) }
  scope :matching_name, ->(query) { joins(:figure).merge(Figure.matching_name(query)) }
  # A code part names a player by short name (HART) or sort name (HART_JOSH, DE_LA_CRUZ_ELLY).
  scope :named_in_code, ->(part) {
    code_form = ->(column) { "UPPER(BTRIM(REGEXP_REPLACE(unaccent(figures.#{column}), '[^[:alnum:]]+', '_', 'g'), '_'))" }
    joins(:figure).where("#{code_form.call('short_name')} = ? OR #{code_form.call('sort_name')} = ?", part.upcase, part.upcase)
  }

  delegate :name, :short_name, :sort_name, :name_segments, :alternate_names,
    *NAME_ATTRIBUTES, *NAME_ATTRIBUTES.map { "#{it}=" }, to: :identity
  alias_method :full_name, :name
  # The name to show: Rizz's when the integration is on (Figure#display_name).
  delegate :display_name, :name_withheld?, to: :identity

  def sport
    super || team&.sport
  end
  
  def photo_url
    photo_urls&.first
  end
  alias_method :logo_url, :photo_url

  def primary_position
    roles.find_by(primary: true)&.position
  end
  alias_method :position, :primary_position
  
  def secondary_positions
    positions.where.not(id: primary_position&.id)
  end
  
  def add_position(position, primary: false)
    roles.where(primary: true).update_all(primary: false) if primary
    roles.create position: position, primary: primary
  end

  def calculate_attempt_stats(attempts, since = 1.week.ago)
    total_attempts = attempts.size
    correct_attempts = attempts.count &:correct?

    recent_attempts = attempts.where("created_at >= ?", since)
    recent_total = recent_attempts.size
    recent_correct = recent_attempts.count &:correct?

    {
      total_attempts: total_attempts,
      correct_attempts: correct_attempts,
      accuracy: total_attempts > 0 ? (correct_attempts.to_f / total_attempts * 100).round : 0,
      recent_total: recent_total,
      recent_correct: recent_correct,
      recent_accuracy: recent_total > 0 ? (recent_correct.to_f / recent_total * 100).round : 0
    }
  end

  private

  def identity
    figure || build_figure
  end

  def attach_figure_identity
    pending = identity
    return if pending.persisted?

    code = "FIGURE-#{entity_code.presence || SecureRandom.uuid.upcase}"
    existing = EntityCode.resolve(Figure, code)
    if existing
      existing.assign_attributes pending.changes.slice(*NAME_ATTRIBUTES).transform_values(&:last)
      self.figure = existing
    else
      pending.entity_code = code
    end
  end
end
