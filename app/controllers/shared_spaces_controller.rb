class SharedSpacesController < ApplicationController
  before_action :authenticate_ace!

  def show
    @manage_places_url = RizzSignIn::PlacesClient.manage_url

    unless RizzSignIn.configuration.configured?
      @state = :disabled
      return
    end

    binding = current_ace.active_rizz_binding
    unless binding
      @state = :unlinked
      return
    end

    response = RizzSignIn::PlacesClient.fetch(rizz_sub: binding.rizz_sub)
    case response.status
    when :ok
      @shared_space = SharedSpaceTeams.call(
        places: response.places,
        trips: response.trips,
        current_zone: response.current_zone
      )
      @engagement_summary = Engagements::Summary.new(@shared_space.all_teams, current_ace)
      @state = @shared_space.empty? ? :empty : :ready
    when :disconnected, :not_found
      @state = :disconnected
    when :disabled
      @state = :disabled
    else
      @state = :unavailable
    end
  end
end
