class Logo < ApplicationRecord
  include VisualAssetPeriod
  belongs_to :owner, polymorphic: true
  validates :owner_type, inclusion: { in: %w[Sport League Conference Division Team] }

  def image
    asset_representations.sort_by { |asset| [asset.file_format == "svg" ? 1 : 0, asset.entity_code.to_s] }
      .find { |asset| asset.view == "default" && asset.file.attached? }&.file
  end
end
