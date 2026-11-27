module SharedSpacesHelper
  def shared_space_jump_nav(shared_space)
    eras = shared_space.home_eras + shared_space.trip_eras
    return "".html_safe if eras.size < 2

    tag.nav class: "shared-space-jump", aria: { label: t("shared_space.jump_to_era") } do
      safe_join(eras.map do |era|
        link_to "##{era.dom_anchor}", class: [ "shared-space-jump-pill", ("is-trip" if era.trip?), ("is-active-now" if era.active_now) ].compact.join(" ") do
          tag.span(era.span_label, class: "shared-space-jump-span") +
            tag.span(era.label, class: "shared-space-jump-label")
        end
      end)
    end
  end

  def shared_space_era_card(era, summary:)
    tag.article id: era.dom_anchor, class: [ "shared-space-era", ("is-active-now" if era.active_now), ("is-trip" if era.trip?) ].compact.join(" ") do
      shared_space_year_rail(era) +
        tag.div(class: "shared-space-era-body") do
          shared_space_era_header(era) + shared_space_era_teams(era, summary: summary)
        end
    end
  end

  def shared_space_year_rail(era)
    lines = era.rail_lines
    tag.div class: "shared-space-rail", aria: { label: era.span_label } do
      if lines.size == 2
        tag.span(lines.first, class: "shared-space-rail-year") +
          tag.span("–", class: "shared-space-rail-dash", aria: { hidden: true }) +
          tag.span(lines.last, class: "shared-space-rail-year")
      else
        tag.span(lines.first, class: "shared-space-rail-year")
      end
    end
  end

  def shared_space_era_header(era)
    subtitle = era.city_name.presence
    subtitle = nil if subtitle&.casecmp?(era.label.to_s)

    tag.header class: "shared-space-era-header" do
      left = tag.div class: "shared-space-era-heading" do
        badges = shared_space_era_badges(era)
        title = tag.h3(era.label, class: "shared-space-era-title")
        place_line = subtitle ? tag.p(subtitle, class: "shared-space-era-place") : "".html_safe
        badges + title + place_line
      end

      count_badge = if era.direct_teams.any?
        tag.span t("shared_space.direct_teams_count", count: era.direct_teams.size), class: "shared-space-era-count"
      else
        "".html_safe
      end

      left + count_badge
    end
  end

  def shared_space_era_badges(era)
    pills = []
    if era.active_now
      pills << tag.span(icon("pin", size: 13) + tag.span(t("shared_space.current_here")), class: "shared-space-badge is-current")
    elsif era.is_home
      pills << tag.span(icon("home", size: 13) + tag.span(t("shared_space.current_home")), class: "shared-space-badge is-home")
    end

    kind_key = era.kind.to_s.downcase
    kind_label = t("shared_space.kinds.#{kind_key}", default: kind_key.humanize) if kind_key.present?
    pills << tag.span(kind_label, class: "shared-space-badge") if kind_label.present?

    return "".html_safe if pills.empty?

    tag.div safe_join(pills), class: "shared-space-era-badges"
  end

  def shared_space_era_teams(era, summary:)
    parts = []

    if era.direct_teams.any?
      parts << tag.ul(class: "shared-space-team-grid") do
        safe_join(era.direct_teams.map { |team| shared_space_team_card(team, summary: summary) })
      end
    end

    if era.regional_teams.any?
      region = era.state_name.presence || "this region"
      summary_key = era.direct_teams.any? ? "shared_space.regional_teams_summary" : "shared_space.regional_only_summary"
      parts << tag.details(class: "shared-space-regional", open: era.direct_teams.empty?) do
        tag.summary(class: "shared-space-regional-toggle") do
          icon("map", size: 16) +
            tag.span(t(summary_key, region: region, count: era.regional_teams.size)) +
            icon("chevron-down", size: 16, class: "shared-space-regional-chevron")
        end +
          tag.ul(class: "shared-space-team-grid") do
            safe_join(era.regional_teams.map { |team| shared_space_team_card(team, summary: summary) })
          end
      end
    end

    if parts.empty?
      message = if era.state_name.present?
        t("shared_space.no_teams_in_place_or_state", place: era.label, region: era.state_name)
      else
        t("shared_space.no_teams_in_place", place: era.label)
      end
      parts << tag.p(message, class: "shared-space-era-empty")
    end

    safe_join(parts)
  end

  def shared_space_team_card(team, summary:)
    tag.li class: "shared-space-team-card", draggable: true, data: tier_lists_draggable_data(team) do
      identity = tag.div class: "shared-space-team-top" do
        entity_avatar(team) +
          tag.div(class: "shared-space-team-copy") do
            link_to(team.name, team, class: "shared-space-team-name") +
              tag.div(class: "shared-space-team-meta") do
                safe_join([
                  (entity_link(team.league) if team.league),
                  shared_space_team_venue(team)
                ].compact)
              end
          end
      end

      actions = tag.div class: "shared-space-team-actions" do
        engagements_radial_bar_for(team, summary: summary, actor: current_ace) +
          link_to(new_game_round_path(team_id: team.id), class: "tool-link shared-space-practice-link") do
            icon("player-play", size: 15) + tag.span(t("shared_space.practice_team"))
          end
      end

      identity + actions
    end
  end

  def shared_space_team_venue(team)
    return unless team.stadium

    city_label = [ team.stadium.name, team.stadium.city&.name ].compact_blank.uniq.join(" · ")
    tag.span class: "shared-space-team-venue" do
      icon("building-stadium", size: 14) + tag.span(city_label)
    end
  end

  def shared_space_empty_state(state, manage_url:)
    glyph = case state
    when :unlinked then "compass"
    when :disconnected then "lock"
    when :unavailable then "info-circle"
    else "pin"
    end

    action = case state
    when :unlinked
      if manage_url.present?
        link_to(t("shared_space.manage_in_rizz"), manage_url, class: "game-button", target: "_blank", rel: "noopener")
      else
        link_to(t("shared_space.browse_all_teams"), teams_path, class: "tool-button")
      end
    when :disconnected, :empty
      if manage_url.present?
        link_to(t("shared_space.states.#{state}.cta"), manage_url, class: "game-button", target: "_blank", rel: "noopener")
      end
    when :unavailable
      link_to(t("shared_space.states.unavailable.cta"), shared_space_path, class: "tool-button")
    end

    tag.section class: "round-panel play-empty shared-space-state" do
      safe_join([
        icon(glyph, size: 28),
        tag.h2(t("shared_space.states.#{state}.title"), class: "profile-section-title"),
        tag.p(t("shared_space.states.#{state}.body")),
        action
      ].compact)
    end
  end
end
