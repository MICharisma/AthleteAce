class Admin::CapturesController < ApplicationController
  before_action :authenticate_ace!
  before_action :require_admin!
  before_action :load_shot

  def create
    attributes = params.expect(capture: [:player_id, :weight])
    player = Player.find(attributes[:player_id])
    player.with_lock { @shot.captures.create!(player: player, weight: attributes[:weight]) }
    redirect_to edit_admin_shot_path(@shot), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_admin_shot_path(@shot), alert: error.record.errors.full_messages.to_sentence, status: :see_other
  end

  def update
    @shot.captures.find(params[:id]).update!(params.expect(capture: [:weight]))
    redirect_to edit_admin_shot_path(@shot), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_admin_shot_path(@shot), alert: error.record.errors.full_messages.to_sentence, status: :see_other
  end

  def destroy
    @shot.captures.find(params[:id]).destroy!
    redirect_to edit_admin_shot_path(@shot), status: :see_other
  end

  private

  def load_shot
    @shot = Shot.find(params[:shot_id])
  end
end
