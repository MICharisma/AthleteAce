class League < ApplicationRecord
  include HasLogos
  belongs_to :sport
  belongs_to :jurisdiction, polymorphic: true
  has_many :conferences, dependent: :destroy
  has_many :divisions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams
  has_many :players, through: :teams
  has_many :stadiums, through: :teams
  has_many :seasons, dependent: :destroy
  has_many :campaigns, through: :seasons
  has_many :contests, through: :campaigns
  has_many :contracts, through: :teams
  has_many :activations, through: :campaigns

  def country
    jurisdiction if jurisdiction_type == "Country"
  end

  def short_name
    abbreviation.present? && !abbreviation.include?("_") ? abbreviation : name
  end

  def context_label(style: :full, include_sport: true)
    base = (style == :short ? short_name : name).to_s.strip.presence
    sport_name = sport&.name.to_s.strip.presence
    return sport_name if base.nil?
    return base unless include_sport && sport_name

    base.downcase.include?(sport_name.downcase) ? base : "#{base} · #{sport_name}"
  end

  def self.ransackable_attributes(auth_object = nil)
    column_names
  end

  def self.ransackable_associations(auth_object = nil)
    reflect_on_all_associations.map { |a| a.name.to_s }
  end
end
