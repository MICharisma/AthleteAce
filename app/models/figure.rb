class Figure < ApplicationRecord
  include SeedObservation
  include AdoptsRizzCode

  UNNAMED = "Unnamed athlete".freeze
  SEARCH_SQL = "unaccent(CONCAT_WS(' ', figures.name, figures.first_name, figures.last_name, " \
    "array_to_string(figures.nicknames, ' '), array_to_string(figures.alternate_names, ' ')))".freeze

  has_many :players, dependent: :restrict_with_error, inverse_of: :figure
  has_many :staff_tenures, dependent: :restrict_with_error
  has_one :rizz_sync, dependent: :delete
  has_many :rizz_names, dependent: :delete_all

  # Name forms by purpose. A source such as Rizz may set them directly; when it
  # doesn't, they are built from first_name and last_name.
  before_validation :fill_name_forms

  validates :name, :short_name, :sort_name, :entity_code, presence: true
  validates :entity_code, uniqueness: true

  # With Rizz enabled, a Figure Rizz has answered for matches only the names
  # Rizz lets AthleteAce search (its search forms, nicknames included), and one
  # whose name Rizz withholds matches nothing. Figures Rizz hasn't been asked
  # about yet match their own name columns.
  RIZZ_SEARCH_SQL = <<~SQL.squish.freeze
    (NOT EXISTS (SELECT 1 FROM rizz_names WHERE rizz_names.figure_id = figures.id AND rizz_names.purpose = 'referring')
      AND #{SEARCH_SQL} ILIKE unaccent(:pattern))
    OR EXISTS (SELECT 1 FROM rizz_names WHERE rizz_names.figure_id = figures.id AND rizz_names.purpose = 'referring'
      AND rizz_names.state = 'current' AND rizz_names.display_name IS NOT NULL
      AND (unaccent(rizz_names.display_name) ILIKE unaccent(:pattern)
        OR EXISTS (SELECT 1 FROM jsonb_array_elements(rizz_names.search_forms) AS form
          WHERE unaccent(form->>'exact_text') ILIKE unaccent(:pattern))))
  SQL

  scope :matching_name, ->(query) {
    pattern = "%#{sanitize_sql_like(query)}%"
    RizzNames.enabled? ? where(RIZZ_SEARCH_SQL, pattern: pattern) : where("#{SEARCH_SQL} ILIKE unaccent(?)", pattern)
  }

  # The name to show for this figure. With Rizz enabled, that is the name Rizz
  # authorizes (rizz_names): a neutral label when Rizz has none AthleteAce may
  # show, and the figure's own name until Rizz has been asked. The name columns
  # stay AthleteAce's source data and are never overwritten from Rizz.
  def display_name(purpose: "referring")
    own = purpose == "short" ? short_name : name
    return own unless RizzNames.enabled?

    row = rizz_name(purpose)
    row ? row.label || RizzNames::NEUTRAL : own
  end

  # Rizz has no name AthleteAce may show for this figure. Games leave such
  # figures out, since a neutral label can't be an answer.
  def name_withheld?(purpose: "referring")
    return false unless RizzNames.enabled?

    row = rizz_name(purpose)
    row.present? && row.label.nil?
  end

  def rizz_name(purpose)
    rizz_names.find { it.purpose == purpose }
  end

  private

  # Changing a name part rebuilds every form that the same change didn't set.
  def fill_name_forms
    rebuild = will_save_change_to_first_name? || will_save_change_to_last_name?
    parts = [first_name, last_name].map { it.to_s.strip }
    fill = lambda do |form, value|
      self[form] = value if self[form].blank? || (rebuild && !will_save_change_to_attribute?(form))
    end
    fill.call "name", parts.compact_blank.join(" ").presence || UNNAMED
    fill.call "name_segments", parts.compact_blank.presence || [name]
    fill.call "short_name", parts.last.presence || parts.first.presence || name
    fill.call "sort_name", parts.reverse.compact_blank.join(", ").presence || name
  end
end
