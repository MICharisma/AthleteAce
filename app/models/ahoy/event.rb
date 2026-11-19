class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  self.table_name = "ahoy_events"

  belongs_to :visit
  belongs_to :user, class_name: "Ace", optional: true

  def self.track(name, user:, **properties)
    current_transaction.after_commit do
      Ahoy::Tracker.new(user: user, visit_token: SecureRandom.uuid).track(name, properties)
    end
  end
end
