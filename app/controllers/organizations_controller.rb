class OrganizationsController < ApplicationController
  def index
    @organizations = Organization.includes(current_teams: { league: :sport }).order(:name)
  end

  def show
    @organization = Organization.includes(
      current_teams: { league: :sport },
      organization_affiliations: { team: { league: :sport } }
    ).find(params.expect(:id))
    @current_teams = @organization.current_teams.sort_by { |team| [ team.sport&.name.to_s, team.league&.name.to_s, team.name ] }
    @staff_tenures = @organization.staff_tenures.includes(:figure, :organization, :team).newest_first
  end
end
