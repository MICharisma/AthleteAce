module FigureClaimsHelper
  STATUS_LABELS = { "pending" => "Pending review", "approved" => "Published", "rejected" => "Rejected", "hidden" => "Withdrawn" }.freeze

  def figure_claim_status(claim_or_status)
    STATUS_LABELS.fetch(claim_or_status.is_a?(String) ? claim_or_status : claim_or_status.moderation_status)
  end

  # One line naming who, how and what, e.g. "Jordan Reyes · Invests in · Harbor Coffee".
  def figure_claim_summary(claim)
    target = case claim
    when FigureBusinessRelationship then claim.business.name
    when FigurePracticeRelationship
               [ claim.protocol&.name, claim.practices.map(&:name).to_sentence.presence ].compact.join(" as ").presence || "No target yet"
    when AttributedStatement then truncate(claim.text, length: 80)
    end
    kind = claim.is_a?(AttributedStatement) ? claim.attribution_kind : claim.predicate
    [ claim.figure.name, kind.humanize, target ].join(" · ")
  end

  def claim_date_range(claim)
    return if claim.start_date.blank? && claim.end_date.blank?

    "#{claim.start_date.presence || 'Unknown start'} to #{claim.end_date.presence || 'unknown end'}"
  end

  def claim_text_field(form, field, value, label: field.to_s.humanize, hint: nil, **options)
    tag.div do
      safe_join [ form.label(field, label), form.text_field(field, value: value, class: "account-input", **options),
        (tag.p(hint, class: "round-caption") if hint) ].compact
    end
  end

  def claim_text_area(form, field, value, label: field.to_s.humanize, hint: nil)
    tag.div do
      safe_join [ form.label(field, label), form.text_area(field, value: value, rows: 3, class: "moderation-reason"),
        (tag.p(hint, class: "round-caption") if hint) ].compact
    end
  end

  def claim_select(form, field, choices, value, label: field.to_s.humanize, blank: nil)
    tag.div do
      safe_join [ form.label(field, label), form.select(field, options_for_select(choices, value), { include_blank: blank }, class: "account-input") ]
    end
  end

  PARTIAL_DATE_HINT = "YYYY, YYYY-MM or YYYY-MM-DD. Leave blank if unknown.".freeze
end
