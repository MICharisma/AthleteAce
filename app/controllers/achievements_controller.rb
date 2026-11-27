class AchievementsController < ApplicationController
  before_action :authenticate_ace!, except: %i[ index show ]
  before_action :require_posting_access!, only: %i[new create]
  before_action :require_admin!, only: %i[ edit update destroy ]
  before_action :set_achievement, only: %i[ show edit update destroy ]

  # GET /achievements or /achievements.json
  def index
    @achievements = Achievement.visible_to(current_ace).unhidden_for(current_ace).includes(:target, highlights: :quest).order(:name)
    @engagement_summary = Engagements::Summary.new(@achievements, current_ace)
  end

  # GET /achievements/1 or /achievements/1.json
  def show
    @highlights = @achievement.highlights
      .visible_to(current_ace)
      .where(quest: Quest.visible_to(current_ace))
      .includes(:quest)
      .to_a
      .sort_by { |highlight| highlight.quest.name.downcase }

    @quest_goals = if current_ace
      current_ace.goals
        .where(quest_id: @highlights.map(&:quest_id))
        .includes(:goal_achievements, quest: { highlights: :achievement })
        .index_by(&:quest_id)
    else
      {}
    end

    @ace_entries = if current_ace
      GoalAchievement.joins(:goal)
        .where(achievement: @achievement, goals: { ace_id: current_ace.id, quest_id: Quest.approved.select(:id) })
        .includes(goal: [ :quest, :goal_achievements ])
        .to_a
    else
      []
    end

    @primary_entry = @ace_entries.find { |entry| entry.completed_at.nil? } || @ace_entries.first
    @primary_goal = @primary_entry&.goal
    @player_count = @primary_entry&.target_player_count || @achievement.fixed_roster_requirement || @achievement.roster_snapshot&.fetch(:ids)&.size
    @earned_count = @achievement.approved? ? GoalAchievement.completed.joins(:goal).where(achievement: @achievement).distinct.count("goals.ace_id") : 0
    @engagement_summary = Engagements::Summary.new([ @achievement, *@highlights.map(&:quest) ], current_ace)
  end

  # GET /achievements/new
  def new
    @achievement = Achievement.new(target_type: params[:target_type].presence_in(Achievement::TARGET_TYPES), target_id: params[:target_id])
    @target_type = params[:target_type] || 'Team'
  end

  # GET /achievements/1/edit
  def edit
    @target_type = @achievement.target_type
  end

  # POST /achievements or /achievements.json
  def create
    @achievement = Achievement.new(achievement_params)
    @achievement.created_by = current_ace
    quest_id = params[:achievement][:quest_id]
    quest = Quest.visible_to(current_ace).find(quest_id) if quest_id.present?

    respond_to do |format|
      if @achievement.save
        # Create a highlight if a quest was selected
        if quest_id.present?
          Highlight.create!(quest: quest, achievement: @achievement, created_by: current_ace)
        end

        format.html { redirect_to @achievement, notice: "Achievement was successfully created." }
        format.json { render :show, status: :created, location: @achievement }
      else
        @target_type = @achievement.target_type || params[:achievement][:target_type] || 'Team'
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @achievement.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /achievements/1 or /achievements/1.json
  def update
    @achievement.moderation_editor = current_ace
    respond_to do |format|
      if @achievement.update(achievement_params)
        format.html { redirect_to @achievement, notice: "Achievement was successfully updated." }
        format.json { render :show, status: :ok, location: @achievement }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @achievement.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /achievements/1 or /achievements/1.json
  def destroy
    @achievement.destroy!

    respond_to do |format|
      format.html { redirect_to achievements_path, status: :see_other, notice: "Achievement was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # GET /achievements/target_options
  def target_options
    model = params[:type].presence_in(Achievement::TARGET_TYPES)&.constantize
    if model
      options = model.all.map { |obj| { id: obj.id, name: obj.try(:name) || obj.try(:title) || obj.to_s } }
      render json: options
    else
      render json: []
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_achievement
      @achievement = Achievement.visible_to(current_ace).find(params.require(:id))
    end

    # Only allow a list of trusted parameters through.
    def achievement_params
      params.require(:achievement).permit(:name, :description, :target_id, :target_type, :roster_level)
    end
end
