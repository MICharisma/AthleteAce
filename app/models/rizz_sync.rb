# A Person's standing with Rizz. States:
#   pending       not yet sent
#   synced        placed in a Rizz entity, whose code the person adopted
#   review        held by Rizz until someone decides an identity review
#   merge_needed  Rizz placed the person in an entity another Person holds
#   failed        the last attempt could not reach Rizz or conflicted
#   skipped       nothing Rizz can import (no athletic profile or no name)
class RizzSync < ApplicationRecord
  STATES = %w[pending synced review merge_needed failed skipped].freeze

  belongs_to :person

  validates :state, inclusion: { in: STATES }
  validates :person_id, uniqueness: true
end
