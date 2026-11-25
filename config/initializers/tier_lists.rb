# frozen_string_literal: true

logo_avatar = lambda do |record|
  image = record.try(:primary_logo)&.image
  if image&.attached?
    Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
  else
    record.try(:logo_url).presence
  end
end

team_colors = lambda do |team|
  next [] unless team

  [ team.primary_color, team.secondary_color ].select { |c| TeamPalette.valid_color?(c) }
end

TierLists.configure do |config|
  config.list_label = "Playbook"
  config.owner_class_name = "Ace"
  config.owner_resolver = ->(controller) { controller.current_ace }
  config.authenticate_owner = ->(controller) { controller.authenticate_ace! }
  config.default_owner = -> { Ace.first }
  config.default_item_classes = %w[Team Player League Sport]

  config.register_content_source(
    "Team",
    records: ->(scope:) {
      rel = Team.includes(:league, primary_logo: { asset_representations: { file_attachment: :blob } })
      rel = rel.joins(:league).where(leagues: { name: scope[:league] }) if scope[:league].present?
      rel = rel.where.not(primary_color: [ nil, "" ]) if scope[:with_colors]
      rel
    },
    designation: ->(team) { team.name },
    expression: ->(team) { [ team.abbreviation, team.league&.name ].compact_blank.join(" · ").presence },
    avatar: logo_avatar,
    colors: team_colors
  )

  config.register_content_source(
    "Player",
    records: ->(scope:) {
      rel = Player.includes(:team, captures: { shot: { image_attachment: :blob } })
      rel = rel.joins(:shots).distinct if scope[:with_photos]
      rel = rel.joins(team: :league).where(leagues: { name: scope[:league] }) if scope[:league].present?
      rel
    },
    designation: ->(player) { player.display_name },
    expression: ->(player) { [ player.current_position, player.team&.abbreviation || player.team&.name ].compact_blank.join(" · ").presence },
    avatar: ->(player) { player.photo_url.presence },
    colors: ->(player) { team_colors.call(player.team) }
  )

  config.register_content_source(
    "League",
    records: ->(scope:) { League.includes(:sport, primary_logo: { asset_representations: { file_attachment: :blob } }) },
    designation: ->(league) { league.name },
    expression: ->(league) { league.sport&.name },
    avatar: logo_avatar
  )

  config.register_content_source(
    "Conference",
    records: ->(scope:) { Conference.includes(primary_logo: { asset_representations: { file_attachment: :blob } }) },
    designation: ->(conf) { conf.name },
    avatar: logo_avatar
  )

  config.register_content_source(
    "Division",
    records: ->(scope:) { Division.includes(primary_logo: { asset_representations: { file_attachment: :blob } }) },
    designation: ->(div) { div.name },
    avatar: logo_avatar
  )

  config.register_content_source(
    "Sport",
    records: ->(scope:) { Sport.includes(primary_logo: { asset_representations: { file_attachment: :blob } }) },
    designation: ->(sport) { sport.name },
    avatar: logo_avatar
  )
end

module TierListsMainAppRouteFallback
  def method_missing(method_name, *args, **kwargs, &block)
    if method_name.to_s.end_with?("_path", "_url") && main_app.respond_to?(method_name)
      main_app.public_send(method_name, *args, **kwargs, &block)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    (method_name.to_s.end_with?("_path", "_url") && main_app.respond_to?(method_name)) || super
  end
end

Rails.application.config.to_prepare do
  TierLists::ApplicationController.helper(TierListsMainAppRouteFallback)
  ApplicationController.helper(TierLists::ListsHelper)
end
