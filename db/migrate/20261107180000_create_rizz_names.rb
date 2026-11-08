# The names Rizz authorizes AthleteAce to show for each Figure, kept apart
# from the Figure's own name columns. Those columns are what AthleteAce sends
# to Rizz; a Rizz label written into them would go back to Rizz as AthleteAce's
# own source data on the next sync. One row per Figure and display purpose,
# plus one event-feed cursor per purpose.
class CreateRizzNames < ActiveRecord::Migration[8.1]
  def change
    create_table :rizz_names do |t|
      t.references :figure, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :purpose, null: false
      t.string :state, null: false, default: "current"
      t.uuid :rizz_entity_id
      t.string :rizz_code
      t.string :display_name
      t.string :sort_key
      t.jsonb :search_forms, null: false, default: []
      t.uuid :form_id
      t.uuid :rule_id
      t.string :view_version
      t.datetime :fetched_at
      t.timestamps
    end
    add_index :rizz_names, [:figure_id, :purpose], unique: true
    add_index :rizz_names, [:purpose, :rizz_entity_id]
    add_check_constraint :rizz_names, "state IN ('current', 'invalidated')", name: "rizz_names_state"

    create_table :rizz_feed_cursors do |t|
      t.string :purpose, null: false, index: { unique: true }
      t.string :cursor
      t.timestamps
    end
  end
end
