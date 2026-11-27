class Achievement < ApplicationRecord
  # Included before Moderatable so Moderatable's visible_to stays the moderation boundary.
  include Engagements::Engageable
  include Moderatable
  ROSTER_LEVELS = { "mastery" => nil, "fluency" => 15, "conversational" => 8, "introductory" => 3 }.freeze
  TARGET_TYPES = %w[Player Team Division Conference League Sport City State Country Federation PlayerGroup].freeze

  scope :unhidden_for, ->(actor) {
    if actor
      where.not(id: actor.engagements.hide.where(engageable_type: polymorphic_name).select(:engageable_id))
    else
      all
    end
  }

  def tier_lists_presentation
    level_label = target_type == "Team" ? I18n.t("achievements.roster_levels.#{roster_level || 'mastery'}") : nil
    quest_count = highlights.approved.where(quest: Quest.approved).count
    earned_count = goal_achievements.completed.joins(:goal).distinct.count("goals.ace_id")

    {
      eyebrow: [ "Achievement", target_type.underscore.humanize ].compact_blank.join(" · "),
      title: name,
      subtitle: [ target&.name, level_label ].compact_blank.join(" · ").presence,
      body: description.presence,
      badges: [ "Achievement", target&.name, level_label ].compact_blank.uniq,
      stats: {
        "Target" => target_type.underscore.humanize,
        "Quests" => quest_count.positive? ? quest_count : nil,
        "Earned" => earned_count.positive? ? earned_count : nil
      },
      colors: [ "#B45309", "#F59E0B" ]
    }
  end

  has_many :goal_achievements, dependent: :destroy
  PRACTICE_SCOPES = { "PlayerGroup" => :player_group_id, "Team" => :team_id, "Division" => :division_id, "Conference" => :conference_id,
    "League" => :league_id, "Sport" => :sport_id, "City" => :city_id, "State" => :state_id }.freeze

  def fixed_roster_requirement
    ROSTER_LEVELS[roster_level]
  end

  def practice_scope
    return { player_id: target_id, include_inactive: true } if target_type == "Player"

    key = PRACTICE_SCOPES[target_type]
    { key => target_id, include_inactive: true } if key
  end

  def roster_snapshot
    return unless practice_scope && target
    return { ids: [ target_id ], scope: practice_scope } if target_type == "Player"

    return { ids: target.players.pluck(:id), scope: practice_scope } if target_type == "PlayerGroup"

    setup = GameRoundSetup.new(practice_scope)
    players = setup.scoped_players
    if players.none?
      seasonal = setup.season_suggestion
      return { ids: seasonal.subjects.pluck(:id), scope: seasonal.scope_params } if seasonal
    end
    { ids: players.pluck(:id), scope: practice_scope }
  end

  has_many :highlights, dependent: :destroy
  has_many :quests, through: :highlights
  # Presence is checked below, after the type check, so a bogus type is never constantized
  belongs_to :target, polymorphic: true, optional: true

  normalizes :roster_level, with: ->(value) { value.presence }
  validates :roster_level, inclusion: { in: ROSTER_LEVELS.keys }, allow_nil: true
  validates :roster_level, absence: true, unless: -> { target_type == "Team" }
  validates :name, presence: true
  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :target, presence: { message: :required }, if: -> { TARGET_TYPES.include?(target_type) }
  
  # Add this achievement to a quest
  def add_to_quest(quest, position: nil, required: true)
    highlights.create(
      quest: quest,
      position: position,
      required: required
    )
  end
  
  # Remove this achievement from a quest
  def remove_from_quest(quest)
    highlights.where(quest: quest).destroy_all
  end
end
