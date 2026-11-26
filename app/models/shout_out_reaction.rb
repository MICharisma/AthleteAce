class ShoutOutReaction < ApplicationRecord
  KINDS = { "fire" => "Fire", "love" => "Love", "legend" => "Legend" }.freeze
  belongs_to :shout_out
  belongs_to :ace
  validates :kind, inclusion: { in: KINDS.keys }

  after_create_commit do
    Ahoy::Event.track "shout_out_reacted", user: ace, shout_out_id: shout_out_id, kind: kind
  end
end
