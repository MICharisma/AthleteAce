class Quest < ApplicationRecord
  # Included before Moderatable so Moderatable's visible_to stays the moderation boundary.
  include Engagements::Engageable
  include Moderatable
  has_many :highlights, dependent: :destroy
  has_many :achievements, through: :highlights
  has_many :goals, dependent: :destroy
  has_many :aces, through: :goals

  scope :unhidden_for, ->(actor) {
    if actor
      where.not(id: actor.engagements.hide.where(engageable_type: polymorphic_name).select(:engageable_id))
    else
      all
    end
  }
  
  validates :name, presence: true

  def tier_lists_presentation
    required_count = highlights.approved.with_approved_achievement.required.count
    optional_count = highlights.approved.with_approved_achievement.optional.count
    participants = goals.distinct.count(:ace_id)

    {
      eyebrow: "Quest",
      title: name,
      subtitle: required_count.positive? ? "#{required_count} required #{'achievement'.pluralize(required_count)}" : nil,
      body: description.presence,
      badges: [
        "Quest",
        (required_count.positive? ? "#{required_count} required" : nil),
        (optional_count.positive? ? "#{optional_count} optional" : nil)
      ].compact,
      stats: {
        "Required" => required_count,
        "Optional" => optional_count.positive? ? optional_count : nil,
        "Participants" => participants.positive? ? participants : nil
      },
      colors: [ "#4A6500", "#84CC16" ]
    }
  end

  def approved_at
    return unless approved?

    moderation_decisions.where(action: "approved", to_status: "approved", revision: moderation_revision)
      .order(created_at: :desc, id: :desc).pick(:created_at)
  end
  
  # Add an achievement to this quest
  def add_achievement(achievement, position: nil, required: true)
    highlights.create(
      achievement: achievement,
      position: position,
      required: required
    )
  end
  
  # Remove an achievement from this quest
  def remove_achievement(achievement)
    highlights.where(achievement: achievement).destroy_all
  end
  
  # Get required achievements for this quest
  def required_achievements
    achievements.approved.merge(Highlight.approved.required)
  end
  
  # Get optional achievements for this quest
  def optional_achievements
    achievements.approved.merge(Highlight.approved.optional)
  end
  
  # Get teams associated with this quest's achievements
  def associated_teams
    teams = []
    achievements.approved.merge(Highlight.approved).each do |achievement|
      case achievement.target
      when Team
        teams << achievement.target
      when League
        teams.concat(achievement.target.teams)
      when Division
        teams.concat(achievement.target.teams)
      when Conference
        teams.concat(achievement.target.divisions.flat_map(&:teams))
      # Add other target types if needed
      end
    end
    teams.uniq
  end
end
