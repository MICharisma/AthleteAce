class ShoutOutFeed
  def self.ranked(scope, seed:)
    quoted = ShoutOut.connection.quote(seed)
    draw = "(('x' || substr(md5(#{quoted} || ':' || shout_outs.id::text), 1, 13))::bit(52)::bigint + 0.5) / 4503599627370496.0"
    published_at = <<~SQL.squish
      COALESCE((
        SELECT MIN(moderation_decisions.created_at)
        FROM moderation_decisions
        WHERE moderation_decisions.subject_type = 'ShoutOut'
          AND moderation_decisions.subject_id = shout_outs.id
          AND moderation_decisions.action = 'approved'
      ), shout_outs.created_at)
    SQL
    age_in_half_lives = "EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP AT TIME ZONE 'UTC' - #{published_at})) / #{2.days.to_i}"
    log_weight = "LN(1 + SQRT(shout_outs.bid_cents / 100.0)) - LN(2) * (#{age_in_half_lives})"
    priority = "LN(-LN(#{draw})) - (#{log_weight})"
    scope.order(Arel.sql("#{priority} ASC"), id: :desc)
  end
end
