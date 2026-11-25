# frozen_string_literal: true

# This migration comes from tier_lists (originally 20261014000001)
# Creates the lists and listed_items tables with UUIDv7 keys. Ownership is
# polymorphic (owner_type/owner_id) so any host-app model with a uuid
# primary key can own a list. Lists are addressed by slug.
class CreateTierListsTables < ActiveRecord::Migration[8.1]
  def change
    create_table :lists, id: :uuid do |t|
      t.string :name
      t.string :slug, null: false
      t.text :description
      t.integer :mode
      t.integer :privacy
      t.references :owner, polymorphic: true, type: :uuid

      t.timestamps
    end
    add_index :lists, :slug, unique: true

    create_table :listed_items, id: :uuid do |t|
      t.references :list, foreign_key: true, type: :uuid
      t.text :designation
      t.text :expression
      t.references :content, polymorphic: true, type: :uuid
      t.integer :ordering
      t.integer :privacy
      t.uuid :replacing

      t.timestamps
    end
  end
end
