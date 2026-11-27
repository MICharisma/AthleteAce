module CurationHelper
  def draggable_listable_attrs(record, data: {})
    return data.any? ? { data: data } : {} unless listable_record?(record) && respond_to?(:tier_lists_draggable_data)

    { draggable: true, data: tier_lists_draggable_data(record).merge(data) }
  end

  def curation_bar_for(record, summary: nil, compact: false)
    return "".html_safe if record.respond_to?(:approved?) && !record.approved?

    actor = respond_to?(:current_ace) ? current_ace : nil
    parts = [
      (engagements_radial_bar_for(record, summary: summary, actor: actor) if respond_to?(:engagements_radial_bar_for)),
      playbook_item_button(record, compact: compact)
    ].compact
    return "".html_safe if parts.empty?

    classes = [ "entity-curation-bar", ("entity-curation-bar--compact" if compact) ].compact.join(" ")
    tag.div class: classes, data: { entity: record.model_name.singular } do
      safe_join(parts)
    end
  end

  def playbook_item_button(record, compact: false)
    return unless listable_record?(record) && respond_to?(:tier_lists_draggable_data)

    drag_data = tier_lists_draggable_data(record)
    label = drag_data[:tier_listable_label]
    entity_kind = record.model_name.singular
    button_classes = [ "playbook-item-action", ("playbook-item-action--compact" if compact) ].compact.join(" ")
    icon_size = compact ? 15 : 16

    if respond_to?(:ace_signed_in?) && ace_signed_in?
      tag.button(
        type: "button",
        draggable: true,
        class: button_classes,
        title: "Click to add to your active playbook, or drag into Playbook Builder",
        aria: { label: "Add #{label} to playbook" },
        data: drag_data.merge(
          entity: entity_kind,
          controller: "playbook-item",
          action: "click->playbook-item#add",
          playbook_item_type_value: drag_data[:tier_listable_type],
          playbook_item_id_value: drag_data[:tier_listable_id],
          playbook_item_label_value: label,
          playbook_item_url_value: tier_lists.items_builder_path,
          playbook_item_builder_url_value: tier_lists.builder_path
        )
      ) do
        icon("list-numbers", size: icon_size, class: "playbook-item-icon") +
          tag.span("+ Playbook", class: "playbook-item-label", data: { playbook_item_target: "label" })
      end
    else
      link_to new_ace_session_path,
              class: button_classes,
              title: "Sign in to add to a playbook",
              aria: { label: "Sign in to add #{label} to a playbook" },
              data: { entity: entity_kind } do
        icon("list-numbers", size: icon_size, class: "playbook-item-icon") +
          tag.span("+ Playbook", class: "playbook-item-label")
      end
    end
  end

  private

  def listable_record?(record)
    return false unless record && TierLists.content_source_for(record.class)
    return false if record.respond_to?(:approved?) && !record.approved?

    true
  end
end
