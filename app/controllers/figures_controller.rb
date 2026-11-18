class FiguresController < ApplicationController
  def show
    @figure = Figure.find(params.expect(:id))
    @staff_tenures = @figure.staff_tenures.includes(:figure, :organization, :team).chronological
    @business_ties = @figure.figure_business_relationships.published.includes(:business, attestations: :author).by_recency
    @practice_ties = @figure.figure_practice_relationships.published.includes(:protocol, :practices, attestations: :author).by_recency
    @statements = @figure.attributed_statements.published
      .includes(:topic, :observer, :figure_practice_relationship, staff_tenure: :organization, attestations: :author).by_recency
  end
end
