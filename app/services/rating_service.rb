class RatingService
  def self.replace(ace:, rated:, spectrum_id: nil, value: nil, notes: nil)
    Spectrum.visible_to(ace).find(spectrum_id) if spectrum_id.present?
    ace.with_lock do
      existing = ace.ratings.active.find_by(rated: rated, spectrum_id: spectrum_id)
      replacement = Rating.new(ace: ace, rated: rated, spectrum_id: spectrum_id, value: value, notes: notes)
      replacement.validate!
      if existing && existing.value == replacement.value && existing.notes == replacement.notes
        existing
      else
        existing&.update!(archived: true)
        replacement.save!
        replacement
      end
    end
  end
end
