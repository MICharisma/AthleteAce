module InterfaceHelper
  def browse_header(title, eyebrow: "Browse", avatar: nil, &block)
    tag.header class: "browse-header" do
      heading = tag.div do
        tag.p(eyebrow, class: "eyebrow") + tag.h1(title, class: "page-title")
      end
      heading = tag.div(avatar + heading, class: "record-identity") if avatar
      heading + tag.div(class: "page-actions", &block)
    end
  end

  def browse_empty(collection, title)
    return if collection.any?

    tag.section class: "round-panel play-empty" do
      tag.h2("No #{title.downcase} recorded", class: "profile-section-title") +
        tag.p("Try a broader scope or explore another category.") + link_to("Browse", browse_path, class: "tool-button")
    end
  end

  def browse_metadata(facts)
    tag.dl class: "browse-metadata" do
      safe_join(facts.map do |label, value|
        tag.div { tag.dt(label) + tag.dd(value.presence || "Not recorded") }
      end)
    end
  end

  def entity_link record
    return "" unless record

    kind = record.model_name.singular
    image_url = catalog_logo_url(record) || record.logo_url if record.is_a?(Team) || record.is_a?(League)
    data = { entity: kind }
    data[:controller] = "entity-image" if image_url.present?

    link_to record, class: "entity-chip", data: data do
      fallback = icon_for_resource kind, size: 16
      if image_url.present?
        fallback = tag.span(fallback, data: { entity_image_target: "fallback" })
        image = entity_image image_url, "entity-logo"
      end
      safe_join [fallback, image, tag.span(person_name(record))]
    end
  end

  def entity_avatar record, size: :small
    image_url = record.is_a?(Player) ? player_portrait_url(record) : (catalog_logo_url(record) || record.logo_url)
    # No initials for a name Rizz withholds.
    initials = record.try(:name_withheld?) ? "" : person_name(record).split.filter_map { |word| word[0] }.first(3).join.upcase
    tag.span class: "entity-avatar entity-avatar-#{size}", data: {
      entity: record.model_name.singular, controller: "entity-image"
    } do
      fallback = tag.span initials, class: "entity-initials", data: { entity_image_target: "fallback" }
      image = entity_image(image_url, "entity-portrait") if image_url.present?
      safe_join [fallback, image]
    end
  end

  def entity_image(image_url, class_name)
    tag.img src: image_url, alt: "", class: "#{class_name} hidden",
      data: { entity_image_target: "image", action: "load->entity-image#loaded error->entity-image#failed" }
  end

  def player_portrait_url player
    portrait = player.figure.primary_portrait&.file
    player.photo_url || (url_for(portrait) if portrait&.attached?)
  end

  def record_identity record
    tag.div class: "record-identity" do
      entity_avatar(record) + tag.div do
        tag.p(record.model_name.human, class: "eyebrow entity-kind", data: { entity: record.model_name.singular }) +
          link_to(record.name, record, class: "identity-name")
      end
    end
  end
end
