module FigureConnectionsHelper
  BUSINESS_PREDICATES = { "founded" => "Founded", "owns" => "Owns", "invests_in" => "Invests in", "endorses" => "Endorses",
                          "promotes" => "Promotes", "sponsored_by" => "Sponsored by" }.freeze
  PRACTICE_PREDICATES = { "participates_in" => "Participates in", "recommends" => "Recommends", "teaches" => "Teaches",
                          "endorses" => "Endorses" }.freeze
  ATTRIBUTIONS = { "direct_quote" => "Direct quote", "attributed_paraphrase" => "Attributed paraphrase",
                   "self_stated_value" => "Self-stated value", "observer_characterization" => "Observer characterization" }.freeze
  PERIODS = { "reported_current" => "Reported current", "historical" => "Historical", "planned" => "Planned", "unknown" => "Dates unknown" }.freeze

  def business_predicate_label(claim)
    BUSINESS_PREDICATES.fetch(claim.predicate)
  end

  def practice_predicate_label(claim)
    PRACTICE_PREDICATES.fetch(claim.predicate)
  end

  # Time context that never turns a missing end date into "current".
  def relationship_period(claim)
    range = [ claim.start_date, claim.end_date ]
    known = "#{claim.start_date || 'Unknown start'} to #{claim.end_date || 'unknown end'}" if range.any?
    return "Founded #{claim.start_date || '(date unknown)'}" if claim.try(:founded?)

    case claim.temporal_state
    when "reported_current" then [ "Reported current as of #{claim.as_of_date}", ("since #{claim.start_date}" if claim.start_date) ].compact.join(", ")
    when "historical" then "Historical · #{known || 'period unknown'}"
    when "planned" then "Planned#{" · from #{claim.start_date}" if claim.start_date}"
    else [ "Current status unknown", known ].compact.join(" · ")
    end
  end

  def compensation_label(claim)
    return unless claim.predicate.in?(FigureBusinessRelationship::COMPENSATED_PREDICATES)

    { "documented_paid" => "Paid (documented)", "documented_unpaid" => "Unpaid (documented)",
      "unknown" => "Compensation unknown" }.fetch(claim.compensation)
  end

  def attestation_author(attestation)
    return link_to(attestation.author.display_name, figure_path(attestation.author), class: "connection-link") if attestation.author

    attestation.author_name.presence || "Author unknown"
  end

  def attestation_source(attestation)
    [ attestation.source_title, attestation.publisher ].compact_blank.join(", ").presence
  end

  def period_options
    PERIODS.map { |value, label| [ label, value ] }
  end

  def filter_links(param, options, current, base: {}, label: param.to_s.humanize)
    links = [ tag.span("#{label}:", class: "round-caption"), link_to("All", url_for(base.merge(param => nil, page: nil)), class: "tool-link", aria: { current: (current.nil? ? "page" : nil) }) ]
    options.each do |label, value|
      links << link_to(label, url_for(base.merge(param => value, page: nil)), class: "tool-link", aria: { current: (current == value ? "page" : nil) })
    end
    tag.nav(safe_join(links), class: "page-actions", aria: { label: "Filter by #{param.to_s.humanize(capitalize: false)}" })
  end
end
