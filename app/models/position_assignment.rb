# A position observed for one subject: what a roster listed for a season
# (RosterEntry), what a player did in a game in order (Appearance), or a
# curated career summary (Player). Sequence orders positions within a game
# and lets one position recur (LF, then 1B, then LF).
class PositionAssignment < ApplicationRecord
  include SeedObservation

  SUBJECT_TYPES = %w[Player RosterEntry Appearance].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :position

  validates :subject_type, inclusion: { in: SUBJECT_TYPES }
  validates :sequence, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :sequence, uniqueness: { scope: %i[subject_type subject_id] }, allow_nil: true
  validates :position_id, uniqueness: { scope: %i[subject_type subject_id], conditions: -> { where(sequence: nil) } }, if: -> { sequence.nil? }
  validates :primary, uniqueness: { scope: %i[subject_type subject_id], message: "position already exists for this subject" }, if: :primary?
  validate :position_matches_player_sport
  validate do
    errors.add :statistics, "must be a mapping" unless statistics.is_a?(Hash)
  end

  scope :in_order, -> { order(Arel.sql("position_assignments.primary DESC, position_assignments.sequence ASC NULLS LAST, position_assignments.id ASC")) }

  # Every assignment that describes this player, at any scope.
  def self.for_player(player)
    where(subject: player)
      .or(where(subject_type: "RosterEntry", subject_id: player.roster_entries.select(:id)))
      .or(where(subject_type: "Appearance", subject_id: player.appearances.select(:id)))
  end

  def player
    case subject
    when Player then subject
    when RosterEntry, Appearance then subject.player
    end
  end

  private

  def position_matches_player_sport
    sport = player&.sport
    return unless sport && position
    errors.add :position, "must belong to the player's sport" unless position.sport_id == sport.id
  end
end
