# A claim supported by Attestations.
module Attested
  extend ActiveSupport::Concern

  included do
    has_many :attestations, -> { order(:entity_code) }, as: :claim, dependent: :restrict_with_error
  end
end
