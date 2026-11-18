class BusinessesController < ApplicationController
  include FigureConnectionBrowsing

  def index
    @predicate = params[:predicate].presence_in(FigureBusinessRelationship::PREDICATES)
    ties = FigureBusinessRelationship.published
    ties = ties.where(predicate: @predicate) if @predicate
    @people_counts = ties.group(:business_id).distinct.count(:figure_id)
    @pagy, @businesses = pagy(Business.where(id: @people_counts.keys).order(:name, :entity_code), limit: 25)
  end

  def show
    @business = Business.find(params.expect(:id))
    @predicate = params[:predicate].presence_in(FigureBusinessRelationship::PREDICATES)
    ties = @business.figure_business_relationships.published.in_period(period_filter)
      .includes(:business, attestations: :author).by_recency
    ties = ties.where(predicate: @predicate) if @predicate
    group_by_person ties
  end
end
