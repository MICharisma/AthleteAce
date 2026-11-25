# frozen_string_literal: true

# This migration comes from tier_lists (originally 20261124000004)
class AddSubjectToLists < ActiveRecord::Migration[8.1]
  def change
    add_column :lists, :subject_type, :string
    add_column :lists, :subject_id, :uuid
    add_index :lists, %i[subject_type subject_id], name: "index_lists_on_subject"
  end
end
