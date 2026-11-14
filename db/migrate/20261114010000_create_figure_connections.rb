# Sourced connections between Figures and businesses, practices and their own
# words (AA-212). Each claim is a typed record with a stable code; supporting
# evidence lives in attestations rather than a claim-level source column.
class CreateFigureConnections < ActiveRecord::Migration[8.1]
  BUSINESS_PREDICATES = %w[founded owns invests_in endorses promotes sponsored_by].freeze
  PRACTICE_PREDICATES = %w[participates_in recommends teaches endorses].freeze
  TEMPORAL_STATES = %w[reported_current historical planned unknown].freeze
  COMPENSATIONS = %w[documented_paid documented_unpaid unknown].freeze
  ATTRIBUTION_KINDS = %w[direct_quote attributed_paraphrase self_stated_value observer_characterization].freeze
  CONTENT_FORMS = %w[text link image video].freeze
  CLAIM_TYPES = %w[FigureBusinessRelationship FigurePracticeRelationship AttributedStatement].freeze

  def change
    create_table :businesses do |t|
      t.string :name, null: false
      t.string :url
      t.integer :founded_year
      t.text :description
      t.string :entity_code, null: false
      t.jsonb :source, null: false, default: {}
      t.jsonb :details, null: false, default: {}
      t.timestamps
      t.index :entity_code, unique: true
      t.index :name
    end

    create_table :figure_business_relationships do |t|
      t.references :figure, null: false, foreign_key: true
      t.references :business, null: false, foreign_key: true
      t.string :predicate, null: false
      t.string :start_date
      t.string :end_date
      t.string :temporal_state, null: false, default: "unknown"
      t.string :as_of_date
      t.string :compensation, null: false, default: "unknown"
      t.text :compensation_description
      t.string :vehicle_name
      t.text :context
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.check_constraint in_list("predicate", BUSINESS_PREDICATES), name: "figure_business_relationships_predicate"
      t.check_constraint in_list("temporal_state", TEMPORAL_STATES), name: "figure_business_relationships_temporal_state"
      t.check_constraint in_list("compensation", COMPENSATIONS), name: "figure_business_relationships_compensation"
    end

    create_table :practices do |t|
      t.string :name, null: false
      t.text :description
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.index :name
    end

    create_table :protocols do |t|
      t.string :name, null: false
      t.text :description
      t.text :routine
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.index :name
    end

    create_table :figure_practice_relationships do |t|
      t.references :figure, null: false, foreign_key: true
      t.references :protocol, foreign_key: true
      t.string :predicate, null: false
      t.text :interpretation
      t.string :start_date
      t.string :end_date
      t.string :temporal_state, null: false, default: "unknown"
      t.string :as_of_date
      t.text :context
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.check_constraint in_list("predicate", PRACTICE_PREDICATES), name: "figure_practice_relationships_predicate"
      t.check_constraint in_list("temporal_state", TEMPORAL_STATES), name: "figure_practice_relationships_temporal_state"
    end

    create_table :practice_connections do |t|
      t.references :figure_practice_relationship, null: false, foreign_key: { on_delete: :cascade }
      t.references :practice, null: false, foreign_key: true
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.index [ :figure_practice_relationship_id, :practice_id ], unique: true, name: "index_practice_connections_uniquely"
    end

    create_table :topics do |t|
      t.string :name, null: false
      t.text :description
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.index :name, unique: true
    end

    create_table :attributed_statements do |t|
      t.references :figure, null: false, foreign_key: true
      t.string :attribution_kind, null: false
      t.text :text, null: false
      t.references :topic, foreign_key: true
      t.references :figure_practice_relationship, foreign_key: true
      t.references :staff_tenure, foreign_key: true
      t.references :observer, foreign_key: { to_table: :figures }
      t.string :observer_name
      t.string :statement_date
      t.text :context
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.check_constraint in_list("attribution_kind", ATTRIBUTION_KINDS), name: "attributed_statements_attribution_kind"
    end

    create_table :attestations do |t|
      t.references :claim, polymorphic: true, null: false
      t.string :content_form, null: false
      t.text :body
      t.string :url
      t.string :media_url
      t.text :excerpt
      t.string :locator
      t.references :author, foreign_key: { to_table: :figures }
      t.string :author_name
      t.string :source_title
      t.string :publisher
      t.string :published_on
      t.datetime :captured_at
      t.text :context
      t.references :entered_by, foreign_key: { to_table: :aces }
      t.string :entity_code, null: false
      t.timestamps
      t.index :entity_code, unique: true
      t.check_constraint in_list("content_form", CONTENT_FORMS), name: "attestations_content_form"
      t.check_constraint in_list("claim_type", CLAIM_TYPES), name: "attestations_claim_type"
    end
  end

  private

  def in_list(column, values)
    "#{column} IN (#{values.map { |value| "'#{value}'" }.join(', ')})"
  end
end
