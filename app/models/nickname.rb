class Nickname < ApplicationRecord
  has_many :team_namings, dependent: :restrict_with_error
  has_many :teams, -> { distinct }, through: :team_namings

  before_validation { self.text = text&.squish }
  validates :text, presence: true, uniqueness: { case_sensitive: false }

  def to_s
    text
  end
end
