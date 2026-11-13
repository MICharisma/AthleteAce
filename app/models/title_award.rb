# A title from a competition. The recipient is a team's entry (winner), a
# person (player), or a person representing an entry (both).
class TitleAward < ApplicationRecord
  include SeedObservation
  belongs_to :contest
  belongs_to :winner, class_name: "Contestant", optional: true
  belongs_to :player, optional: true
  has_one :campaign, through: :winner
  has_one :team, through: :campaign

  scope :team_titles, -> { where(player_id: nil) }
  scope :person_titles, -> { where.not(player_id: nil) }

  validates :key, presence: true, length: { maximum: 80 }, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }, uniqueness: { scope: :contest_id }
  validates :name, presence: true, length: { maximum: 200 }
  validate do
    errors.add :contest, "must be a competition, not a game" if contest&.kind == "game"
    errors.add :base, "needs a winning entry, a player, or both" unless winner || player
    errors.add :winner, "must be entered in this competition" if winner && winner.contest_id != contest_id
    errors.add :player, "must play the competition's sport" if player && contest_sport && player.sport != contest_sport
  end

  # The person when there is one, otherwise the winning team.
  def recipient
    player || team
  end

  private

  def contest_sport
    context = contest&.context
    case context
    when Sport then context
    when League then context.sport
    when Conference, Division then context.league&.sport
    else contest&.season&.league&.sport # Federations and organizations can span sports.
    end
  end
end
