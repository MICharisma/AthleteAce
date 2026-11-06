# Where each Person stands with Rizz, the shared naming service: the Rizz
# entity and code it was placed in, the name snapshot last sent, and whether
# it is waiting on an identity review or a local merge.
class CreateRizzSyncs < ActiveRecord::Migration[8.1]
  def change
    create_table :rizz_syncs do |t|
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.string :state, null: false, default: "pending"
      t.uuid :rizz_entity_id
      t.integer :rizz_version
      t.string :rizz_code
      t.string :source_revision
      t.uuid :review_id
      t.string :last_error
      t.datetime :synced_at
      t.timestamps
    end
    add_index :rizz_syncs, :state
    add_index :rizz_syncs, :rizz_entity_id
    add_check_constraint :rizz_syncs, "state IN ('pending', 'synced', 'review', 'merge_needed', 'failed', 'skipped')", name: "rizz_syncs_state"
  end
end
