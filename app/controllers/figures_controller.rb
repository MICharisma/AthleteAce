class FiguresController < ApplicationController
  def show
    @figure = Figure.find(params.expect(:id))
    @staff_tenures = @figure.staff_tenures.includes(:figure, :organization, :team).chronological
  end
end
