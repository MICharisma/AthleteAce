Engagements.configure do |config|
  config.engageable_types = %w[Player Team Quest Achievement]
  config.actor_resolver = ->(controller) { controller.current_ace }
  config.authenticate_actor = ->(controller) { controller.authenticate_ace! }
  config.sign_in_path = ->(view) { view.main_app.new_ace_session_path }
  config.action_bar_variant = :radial

  config.turbo_stream_renderer = ->(view, **) {
    saved_url = view.request.base_url + view.engagements_create_path
    next unless view.request.referer.to_s.split("?", 2).first&.delete_suffix("/") == saved_url.delete_suffix("/")

    view.turbo_stream.refresh(request_id: nil)
  }
end
