# frozen_string_literal: true

class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  self.table_name = "ahoy_events"

  belongs_to :visit
  belongs_to :user, class_name: "Ace", optional: true

  def self.track(name, user:, **properties)
    tracker = Current.ahoy_tracker
    actor = tracker&.user
    same_actor = tracker.present? && (actor.nil? || user.nil? || actor == user)
    return if same_actor && tracker.exclude?

    visit_token = same_actor ? tracker.visit_token : SecureRandom.uuid
    current_transaction.after_commit do
      if same_actor && user.present? && tracker.visit&.user_id.nil?
        tracker.authenticate(user)
      end
      Ahoy::Tracker.new(user: user, visit_token: visit_token).track(name, properties)
    end
  end
end
