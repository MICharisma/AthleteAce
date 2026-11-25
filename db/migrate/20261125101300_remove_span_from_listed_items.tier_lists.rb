# frozen_string_literal: true

# This migration comes from tier_lists (originally 20261125000007)
class RemoveSpanFromListedItems < ActiveRecord::Migration[8.1]
  def change
    remove_column :listed_items, :span, :integer, default: 0, null: false
  end
end
