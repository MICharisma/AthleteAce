class RatingDimensions
  def initialize(ace:, rated:)
    @ace, @rated = ace, rated
  end

  def catalog
    Spectrum.visible_to(@ace).order(:name, :id).to_a
  end

  def eligible
    answered = @ace.ratings.active.where(rated: @rated).pluck(:spectrum_id)
    catalog.reject { |spectrum| answered.include?(spectrum.id) }
  end

  def defaults
    available = eligible
    (%w[Familiarity Skill Affinity].filter_map { |name| available.find { |spectrum| spectrum.name == name } } + available).uniq.first(3)
  end

  def suggestions
    available = eligible
    choices = @ace.ratings.active.where(spectrum_id: available.map(&:id)).group(:spectrum_id).count
    candidates = available.map do |spectrum|
      { key: spectrum.rating_dimension.key, label: spectrum.name, question: spectrum.description.to_s }
    end
    preferences = available.filter_map do |spectrum|
      { key: spectrum.rating_dimension.key, times_chosen: choices.fetch(spectrum.id) } if choices.key?(spectrum.id)
    end
    provider = Rails.configuration.x.shared_ratings.suggestion_provider || SharedRatings::LLMProvider.from_env
    result = SharedRatings::Suggestions.new(provider: provider).call(
      candidates: candidates, subject: { type: @rated.class.name, name: @rated.is_a?(Player) ? @rated.display_name : @rated.name },
      preferences: preferences, defaults: defaults.map { |spectrum| spectrum.rating_dimension.key }
    )
    current = eligible.index_by { |spectrum| spectrum.rating_dimension.key }
    { suggestions: result.keys.filter_map { |key| { key: key, label: current[key].name } if current.key?(key) }, source: result.source }
  end
end
