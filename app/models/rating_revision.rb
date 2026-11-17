class RatingRevision < ApplicationRecord
  belongs_to :ace

  def self.record! rating, operation:
    create! ace: rating.ace, rating_id: rating.id,
      target_type: rating.target_type, target_id: rating.target_id, spectrum_id: rating.spectrum_id,
      value: rating.value, notes: rating.notes, archived: rating.archived,
      dimension: rating.spectrum.rating_dimension.to_h, operation: operation
  end
end
