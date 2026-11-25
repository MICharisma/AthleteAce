# frozen_string_literal: true

# This migration comes from tier_lists (originally 20261124000005)
class AddStandaloneToLists < ActiveRecord::Migration[7.1]
  def change
    add_column :lists, :standalone, :boolean, default: false, null: false
  end
end
