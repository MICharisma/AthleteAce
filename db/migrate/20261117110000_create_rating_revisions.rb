class CreateRatingRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_revisions do |t|
      t.references :ace, null: false, foreign_key: true
      t.bigint :rating_id, null: false
      t.references :target, polymorphic: true, null: false
      t.bigint :spectrum_id, null: false
      t.bigint :value, null: false
      t.text :notes
      t.boolean :archived, null: false
      t.jsonb :dimension, null: false
      t.string :operation, null: false
      t.datetime :created_at, null: false
      t.index [ :rating_id, :id ]
      t.check_constraint "operation IN ('set', 'archive', 'remove')", name: "rating_revisions_valid_operation"
    end
  end
end
