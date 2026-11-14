class TopicsController < ApplicationController
  include FigureConnectionBrowsing

  def index
    @people_counts = AttributedStatement.published.where.not(topic_id: nil).group(:topic_id).distinct.count(:figure_id)
    @topics = Topic.where(id: @people_counts.keys).order(:name)
  end

  def show
    @topic = Topic.find(params.expect(:id))
    group_by_person @topic.attributed_statements.published
      .includes(:topic, :observer, :figure_practice_relationship, staff_tenure: :organization, attestations: :author).by_recency
  end
end
