# A Protocol's method and the Practices each person connects it with in their
# own sourced association. There is no global list of purposes.
class ProtocolsController < ApplicationController
  include FigureConnectionBrowsing

  def index
    @people_counts = FigurePracticeRelationship.published.where.not(protocol_id: nil).group(:protocol_id).distinct.count(:figure_id)
    @pagy, @protocols = pagy(Protocol.where(id: @people_counts.keys).order(:name, :entity_code), limit: 25)
  end

  def show
    @protocol = Protocol.find(params.expect(:id))
    @predicate = params[:predicate].presence_in(FigurePracticeRelationship::PREDICATES)
    ties = @protocol.figure_practice_relationships.published.in_period(period_filter)
    ties = ties.where(predicate: @predicate) if @predicate
    group_by_person ties.includes(:protocol, :practices, attestations: :author).by_recency
  end
end
