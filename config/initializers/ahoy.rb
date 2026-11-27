# frozen_string_literal: true

class Ahoy::Store < Ahoy::DatabaseStore
end

Ahoy.api = true
Ahoy.geocode = false
Ahoy.user_method = :current_ace
Ahoy.mask_ips = true
Ahoy.track_bots = Rails.env.test?
Ahoy.exclude_method = ->(controller, request) do
  request&.cookie_jar&.[](:athleteace_analytics_exclude) == "1" ||
    controller&.send(:current_ace)&.then { |ace| ace.admin? || ace.moderator? }
end
