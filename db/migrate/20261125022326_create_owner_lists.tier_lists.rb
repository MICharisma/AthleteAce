# frozen_string_literal: true

# This migration comes from tier_lists (originally 20261124000006)
class CreateOwnerLists < ActiveRecord::Migration[8.1]
  def change
    create_table :owner_lists, id: :uuid do |t|
      t.references :owner, polymorphic: true, null: false, type: :uuid
      t.references :list, null: false, foreign_key: { to_table: :lists }, type: :uuid
      t.boolean :in_bookbag, default: false, null: false
      t.integer :bookbag_position
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :owner_lists, %i[owner_type owner_id list_id], unique: true, name: "index_owner_lists_uniqueness"
    add_index :owner_lists, %i[owner_type owner_id in_bookbag bookbag_position], name: "index_owner_lists_bookbag"
    add_index :owner_lists, %i[owner_type owner_id last_used_at], name: "index_owner_lists_last_used"
  end
end
