module RatingsHelper
  # Display ratings count for a record
  def ratings_count_display(record)
    if record.ratings.active.where(spectrum: Spectrum.visible_to(current_ace)).any?
      tag.div class: "record-stats-count" do
        tag.span pluralize(record.ratings.active.where(spectrum: Spectrum.visible_to(current_ace)).count, "rating"), class: "record-stats-count-value"
      end
    end
  end
  
  # Display ratings details (top 3 spectrums with percentages)
  def ratings_details_display(record)
    return unless record.ratings.active.where(spectrum: Spectrum.visible_to(current_ace)).any?
    
    content = "".html_safe
    record.ratings.active.where(spectrum: Spectrum.visible_to(current_ace)).group(:spectrum_id).count.first(3).each do |spectrum_id, count|
      spectrum = Spectrum.visible_to(current_ace).find(spectrum_id)
      content += tag.div class: "record-stats-detail" do
        "#{spectrum.name}: #{record.normalized_average_rating_on(spectrum)&.*(100)&.round || 'N/A'}%"
      end
    end
    
    content
  end
  
  # Display empty ratings message
  def empty_ratings_display
    tag.div "No ratings yet", class: "record-stats-empty"
  end
  
  # Combine all ratings display elements
  def ratings_stats_display(record)
    if record.ratings.active.where(spectrum: Spectrum.visible_to(current_ace)).any?
      ratings_count_display(record) + ratings_details_display(record)
    else
      empty_ratings_display
    end
  end
  
  def rating_rows_id record
    dom_id record, :rating_rows
  end

  def rating_row_id record, spectrum
    dom_id record, "rating_spectrum_#{spectrum.id}"
  end

  def formatted_rating value
    value.nil? ? "Not rated" : number_with_delimiter(value.round)
  end

  def rating_slider_container record, spectrums
    return unless record.is_ratable?

    content_for(:rating_sliders, "1") unless content_for?(:rating_sliders)

    tag.div class: "rating-container" do
      tag.div id: dom_id(record, :rating_slider_group), class: "rating-slider-group-container", data: {
        controller: "rating-slider",
        action: "dimension-suggestions:select->rating-slider#openDimension",
        rating_spectrum_url: polymorphic_path([record, :ratings], action: :for_spectrums)
      } do
        rows = tag.div id: rating_rows_id(record) do
          render "ratings/slider_rows", record: record, spectrums: spectrums
        end
        picker = render("ratings/dimension_picker", record: record) if current_ace
        safe_join [rows, picker]
      end
    end
  end
end
