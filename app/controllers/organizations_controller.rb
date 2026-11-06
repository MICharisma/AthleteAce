class OrganizationsController < ApplicationController
  def index
    @organizations = Organization.includes(current_organization_affiliations: :team).order(:name)
  end

  def show
    @organization = Organization.includes(organization_affiliations: { team: :league }).find(params.expect(:id))
    @staff_tenures = @organization.staff_tenures.includes(:figure, :organization, :team).chronological
  end
end
