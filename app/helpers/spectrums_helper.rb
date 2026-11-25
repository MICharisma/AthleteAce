module SpectrumsHelper
  def set_selected_spectrum_ids(ids)
    session[:selected_spectrum_ids] = default_spectrums.map(&:id) & Array(ids)
  end

  def set_current_spectrum_id(id)
    set_selected_spectrum_ids [id]
  end

  def selected_spectrums
    @selected_spectrums ||= begin
      requested = params[:spectrum_ids]
      available = default_spectrums
      if requested.is_a?(Array) && (matches = available.select { |spectrum| requested.include?(spectrum.id) }).any?
        matches
      elsif session[:selected_spectrum_ids].is_a?(Array)
        available.select { |spectrum| session[:selected_spectrum_ids].include?(spectrum.id) }
      else
        [available.find { |spectrum| spectrum.name == "Familiarity" } || available.first].compact
      end
    end
  end

  def default_spectrums
    @default_spectrums ||= Spectrum.visible_to(current_ace).order(:name).to_a
  end

  def render_floating_spectrum_picker
    return if default_spectrums.empty?

    selected_ids = selected_spectrums.map(&:id)
    tag.div id: "spectrum-picker", class: "spectrum-picker", data: {
      controller: "spectrum-picker", action: "keydown.esc->spectrum-picker#close",
      spectrum_picker_url_value: spectrum_preference_path
    } do
      toggle = tag.button type: "button", class: "spectrum-picker-toggle tool-button", aria: {
        expanded: false, controls: "spectrum-picker-panel", label: t("ratings.picker.label")
      }, data: { spectrum_picker_target: "toggleButton", action: "spectrum-picker#toggleExpand" } do
        icon("adjustments-horizontal", size: 18, class: "spectrum-picker-icon") +
          tag.span(t("ratings.picker.label"), class: "spectrum-picker-label") +
          tag.span(selected_spectrums.map(&:name).join(", "), data: { spectrum_picker_target: "selectedSummary" }) +
          icon("chevron-down", size: 16, data: { spectrum_picker_target: "toggleIcon" })
      end
      panel = tag.div id: "spectrum-picker-panel", class: "spectrum-picker-panel", hidden: true,
        data: { spectrum_picker_target: "pickerPanel" } do
        multiple = tag.label class: "spectrum-multiple" do
          check_box_tag(:multiple_spectrums, "1", session[:multiple_spectrums] || selected_ids.size > 1,
            data: { spectrum_picker_target: "multiSelectToggle", action: "change->spectrum-picker#handleMultiSelectToggle" }) +
            t("ratings.picker.multiple")
        end
        buttons = tag.div class: "spectrum-buttons" do
          safe_join default_spectrums.map { |spectrum|
            tag.button spectrum.approved? ? spectrum.name : "#{spectrum.name} · In review", type: "button", aria: { pressed: selected_ids.include?(spectrum.id) },
              data: { action: "spectrum-picker#toggleSpectrum", spectrum_picker_target: "spectrumButton", spectrum_id: spectrum.id }
          }
        end
        safe_join [multiple, buttons, tag.p("", role: "status", data: { spectrum_picker_target: "status" })]
      end
      toggle + panel
    end
  end
end
