# frozen_string_literal: true

module AnalyticsTracking
  extend ActiveSupport::Concern

  included do
    helper_method :analytics_context
    before_action :assign_analytics_tracker
  end

  private

  def assign_analytics_tracker
    Current.ahoy_tracker = ahoy
  end

  def analytics_context
    {
      side: current_side,
      page_type: "#{controller_path}.#{action_name}",
      record_id: params[:id],
      path: analytics_path(request.path),
      signed_in: ace_signed_in?,
      enabled: !analytics_excluded?
    }.compact
  end

  def analytics_excluded?
    cookies[:athleteace_analytics_exclude] == "1" ||
      current_ace&.then { |ace| ace.admin? || ace.moderator? }
  end

  def analytics_path(path)
    path.sub(%r{\A/(invite|tokens)/[^/]+}, '/\1/:token')
  end

  def track_analytics(name, properties = {})
    return if analytics_excluded?

    ahoy.track(name, analytics_context.except(:enabled).merge(properties))
  end
end
