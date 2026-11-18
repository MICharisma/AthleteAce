# Practices and the people whose own sourced associations name them. A
# combined filter shows each association once, with every Practice it names.
class PracticesController < ApplicationController
  include FigureConnectionBrowsing

  def index
    @selected_ids = Array(params[:practice_ids]).compact_blank.map(&:to_i)
    @protocol = Protocol.find_by(id: params[:protocol_id]) if params[:protocol_id].present?
    @predicate = params[:predicate].presence_in(FigurePracticeRelationship::PREDICATES)
    published = FigurePracticeRelationship.published
    @people_counts = PracticeConnection.joins(:figure_practice_relationship).merge(published)
      .group(:practice_id).distinct.count("figure_practice_relationships.figure_id")
    @practices = Practice.where(id: @people_counts.keys).order(:name, :entity_code)
    @protocols = Protocol.where(id: published.select(:protocol_id)).order(:name, :entity_code)
    @filtering = @selected_ids.any? || @protocol || @predicate
    group_by_person filtered(published) if @filtering
  end

  def show
    @practice = Practice.find(params.expect(:id))
    @predicate = params[:predicate].presence_in(FigurePracticeRelationship::PREDICATES)
    ties = FigurePracticeRelationship.published.where(id: @practice.practice_connections.select(:figure_practice_relationship_id))
    ties = ties.where(predicate: @predicate) if @predicate
    group_by_person ties.in_period(period_filter).includes(:protocol, :practices, attestations: :author).by_recency
  end

  private

  def filtered(ties)
    ties = ties.where(id: PracticeConnection.where(practice_id: @selected_ids).select(:figure_practice_relationship_id)) if @selected_ids.any?
    ties = ties.where(protocol: @protocol) if @protocol
    ties = ties.where(predicate: @predicate) if @predicate
    ties.in_period(period_filter).includes(:protocol, :practices, attestations: :author).by_recency
  end
end
