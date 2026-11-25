# frozen_string_literal: true

# This migration comes from tier_lists (originally 20261014000002)
# Embeddable items: an optional URL rendered as a lazy <iframe>
# (foundation for richer item types; see README "Embed items" for the
# third-party-cookie caveats).
class AddEmbedUrlToListedItems < ActiveRecord::Migration[8.1]
  def change
    add_column :listed_items, :embed_url, :string
  end
end
