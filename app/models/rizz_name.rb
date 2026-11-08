# The name Rizz authorizes AthleteAce to show for one Figure and display
# purpose ("referring" or "short"). RizzNames keeps these rows in step with
# Rizz; rendering reads them and never calls Rizz.
#
# A current row with no display_name means Rizz has no name AthleteAce may
# show, so the page shows a neutral label. An invalidated row is waiting for
# a refetch and shows the neutral label too.
class RizzName < ApplicationRecord
  PURPOSES = %w[referring short].freeze

  belongs_to :figure

  validates :purpose, inclusion: { in: PURPOSES }
  validates :state, inclusion: { in: %w[current invalidated] }

  def label
    display_name if state == "current"
  end
end
