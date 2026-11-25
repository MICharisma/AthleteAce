# frozen_string_literal: true

# This migration comes from tier_lists (originally 20261123000003)
# Per-item grid span: items default to compact grid tiles (:tile = 0),
# or can stretch across the full row (:full_row = 1) in fractal/grid views.
class AddSpanToListedItems < ActiveRecord::Migration[8.1]
  def change
    add_column :listed_items, :span, :integer, default: 0, null: false
  end
end
