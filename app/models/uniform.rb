class Uniform < ApplicationRecord
  include VisualAssetPeriod
  belongs_to :team
  has_many :uniform_pieces, dependent: :destroy
  has_many :uniform_campaigns, dependent: :destroy
  has_many :campaigns, through: :uniform_campaigns
end
