class Person < ApplicationRecord
  include SeedObservation

  UNNAMED = "Unnamed athlete".freeze
  SEARCH_SQL = "unaccent(CONCAT_WS(' ', people.name, people.first_name, people.last_name, " \
    "array_to_string(people.nicknames, ' '), array_to_string(people.alternate_names, ' ')))".freeze

  has_many :players, dependent: :restrict_with_error, inverse_of: :person
  has_many :staff_tenures, dependent: :restrict_with_error

  # Name forms by purpose. A source such as Rizz may set them directly; when it
  # doesn't, they are built from first_name and last_name.
  before_validation :fill_name_forms

  validates :name, :short_name, :sort_name, :entity_code, presence: true
  validates :entity_code, uniqueness: true

  scope :matching_name, ->(query) { where("#{SEARCH_SQL} ILIKE unaccent(?)", "%#{sanitize_sql_like(query)}%") }

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
