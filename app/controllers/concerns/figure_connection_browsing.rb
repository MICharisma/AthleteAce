# Reverse pages (a Business, Practice, Protocol or Topic) list the people with
# published claims about it once each, alphabetically, with their claims.
module FigureConnectionBrowsing
  extend ActiveSupport::Concern

  PEOPLE_PER_PAGE = 20

  private

  def group_by_person(claims)
    people = Figure.where(id: claims.unscope(:order, :select).select(:figure_id)).order(:name, :entity_code)
    @pagy, @people = pagy(people, limit: PEOPLE_PER_PAGE)
    @claims_by_person = claims.where(figure_id: @people.map(&:id)).group_by(&:figure_id)
  end

  def period_filter
    @period = params[:period].presence_in(TemporalClaim::STATES)
  end
end
