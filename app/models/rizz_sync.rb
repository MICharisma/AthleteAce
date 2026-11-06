# A Figure's standing with Rizz. States:
#   pending       not yet sent
#   synced        placed in a Rizz entity, whose code the figure adopted
#   review        held by Rizz until someone decides an identity review
#   merge_needed  Rizz placed the figure in an entity another Figure holds
#   failed        the last attempt could not reach Rizz or conflicted
#   skipped       nothing Rizz can import (no athletic profile or no name)
class RizzSync < ApplicationRecord
  STATES = %w[pending synced review merge_needed failed skipped].freeze

  belongs_to :figure

  validates :state, inclusion: { in: STATES }
  validates :figure_id, uniqueness: true
end
