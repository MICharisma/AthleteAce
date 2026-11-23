class Admin::ShotsController < ApplicationController
  before_action :authenticate_ace!
  before_action :require_admin!
  before_action { response.headers["Cache-Control"] = "private, no-store" }
  before_action :load_shot, only: [:edit, :update]

  def index
    @shot = Shot.new
    load_library
  end

  def create
    upload = params.expect(shot: [:image, :tags])
    @shot = Shot.new(image: upload[:image], tags: upload[:tags].to_s.split(","))
    if @shot.save
      redirect_to edit_admin_shot_path(@shot), status: :see_other
    else
      load_library
      render :index, status: :unprocessable_content
    end
  end

  def edit
    load_players
  end

  def update
    if @shot.update(tags: params.expect(shot: [:tags])[:tags].to_s.split(","))
      redirect_to edit_admin_shot_path(@shot), status: :see_other
    else
      load_players
      render :edit, status: :unprocessable_content
    end
  end

  private

  def load_shot
    @shot = Shot.find(params[:id])
  end

  def load_library
    @tag = params.permit(:tag)[:tag].to_s.strip
    shots = Shot.with_attached_image.order(created_at: :desc, id: :desc)
    shots = shots.tagged(@tag) if @tag.present?
    shots = shots.untagged_players if params[:unassigned] == "1"
    @pagy, @shots = pagy(shots, limit: 24)
  end

  def load_players
    @captures = @shot.captures.includes(player: :figure).order(:created_at)
    @query = params.permit(:q)[:q].to_s.strip
    return @players = [] if @query.blank?

    matching = Player.matching_name(@query)
    @players = matching.or(Player.joins(:figure).where(entity_code: @query))
      .where.not(id: @shot.captures.select(:player_id)).by_name.limit(25)
  end
end
