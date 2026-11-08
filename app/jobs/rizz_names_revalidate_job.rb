# Refetches every Figure's names once a day, so a lost event can't leave a
# stale name standing, and adds names for newly synced Figures. Does nothing
# unless RIZZ_ENDPOINT is set.
class RizzNamesRevalidateJob < ApplicationJob
  def perform
    RizzNames.new.revalidate if RizzNames.enabled?
  end
end
