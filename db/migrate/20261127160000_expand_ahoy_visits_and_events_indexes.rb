# frozen_string_literal: true

class ExpandAhoyVisitsAndEventsIndexes < ActiveRecord::Migration[8.1]
  def change
    change_table :ahoy_visits, bulk: true do |t|
      t.string :visitor_token
      t.string :ip
      t.text :user_agent
      t.text :referrer
      t.string :referring_domain
      t.text :landing_page
      t.string :browser
      t.string :os
      t.string :device_type
      t.string :country
      t.string :region
      t.string :city
      t.float :latitude
      t.float :longitude
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_term
      t.string :utm_content
      t.string :utm_campaign
      t.string :app_version
      t.string :os_version
      t.string :platform
    end

    add_index :ahoy_visits, [ :visitor_token, :started_at ]
    add_index :ahoy_events, :properties, using: :gin, opclass: :jsonb_path_ops
  end
end
