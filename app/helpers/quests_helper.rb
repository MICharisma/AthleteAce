module QuestsHelper
  def quest_goal quest
    return unless current_ace
    return @quest_goals[quest.id] if @quest_goals

    current_ace.goals.find_by quest: quest
  end

  def quest_activity quest
    first_approval = quest.moderation_decisions.where(action: "approved", to_status: "approved").minimum(:created_at)
    begun, completed = quest.goals.pick(
      Arel.sql("COUNT(DISTINCT ace_id)"),
      Arel.sql("COUNT(DISTINCT ace_id) FILTER (WHERE status = 'completed')")
    )

    { days_alive: (Date.current - (first_approval || quest.created_at).in_time_zone.to_date).to_i, begun: begun, completed: completed }
  end

  def quest_progress goal
    required = goal.quest.highlights.approved.with_approved_achievement.count(&:required?)
    completed = [goal.progress, required].min
    { completed: completed, required: required, percent: required.positive? ? (completed.fdiv(required) * 100).round : 0 }
  end

  def quest_practice_scope(achievement, goal: nil, remaining: false)
    return unless achievement.practice_scope && achievement.target

    goal ||= quest_goal(@quest) if @quest
    entry = if goal
      goal.goal_achievements.loaded? ? goal.goal_achievements.find { |item| item.achievement_id == achievement.id } : goal.goal_achievements.find_by(achievement: achievement)
    end
    scope = entry ? entry.practice_scope : achievement.practice_scope
    if entry && achievement.target_type == "PlayerGroup"
      scope = scope.merge(goal_achievement_id: entry.id)
      scope = scope.merge(practice_filter: "remaining", game_type: "name_ciphers") if remaining
    end
    scope
  end

  def quest_practice_path(achievement, goal: nil, remaining: false, length: 10)
    scope = quest_practice_scope(achievement, goal: goal, remaining: remaining)
    new_game_round_path(scope.merge(length: length)) if scope
  end

  def quest_flash_cards_path(achievement, goal: nil, length: 10)
    scope = quest_practice_scope(achievement, goal: goal)
    flash_cards_path(scope.merge(delay: 5, length: length)) if scope
  end

  def quest_team_match_params(achievement, goal: nil, length: 10)
    scope = quest_practice_scope(achievement, goal: goal)
    scope&.merge(game_type: "on_the_team", length: length)
  end

  # Renders a button for an ace to begin a quest
  # If the ace is already on the quest, shows a different button
  def begin_quest_button(quest, options = {})
    return unless ace_signed_in? && quest.approved?

    existing_goal = quest_goal quest

    if existing_goal
      link_to goal_path(existing_goal), class: "tool-button quest-continue-button #{options[:class]}" do
        content_tag(:span, class: 'quest-button-content') do
          icon("check", size: 18, class: "quest-button-icon") +
          content_tag(:span, 'Continue Quest')
        end
      end
    else
      button_to quest_goals_path(quest), method: :post, class: "game-button quest-begin-button #{options[:class]}" do
        content_tag(:span, class: 'quest-button-content') do
          icon("flag", size: 18, class: "quest-button-icon") +
          content_tag(:span, 'Begin Quest')
        end
      end
    end
  end

  def quest_card_title_link quest
    link_to quest_path(quest), class: "quest-card-link" do
      tag.span(quest.name, class: "quest-card-title") + icon("arrow-right", size: 22, class: "quest-card-arrow")
    end
  end

  def quest_card_actions quest
    actions = [
      begin_quest_button(quest),
      (link_to("Edit", edit_quest_path(quest), class: "tool-link") if can_manage?(quest))
    ].compact
    tag.div safe_join(actions), class: "page-actions" if actions.any?
  end

  def quest_achievements_indicator quest
    required, optional = quest_card_highlights quest
    summary = t "quests.card.required_achievements", count: required.size
    tooltip_id = dom_id quest, :achievements_tooltip_for

    tag.div class: "quest-achievements-indicator" do
      tag.button(type: "button", class: "quest-achievements-badge",
        aria: { label: summary, describedby: tooltip_id }) do
        tag.span(required.size) + icon("medal", size: 18, class: "quest-achievements-icon")
      end +
      tag.div(id: tooltip_id, role: "tooltip", class: "quest-achievements-tooltip") do
        tag.div quest_achievements_tooltip_content(required, optional, summary), class: "quest-achievements-tooltip-card"
      end
    end
  end

  # Returns the number of aces currently on a quest
  def quest_participants_count(quest)
    @quest_participant_counts ? @quest_participant_counts.fetch(quest.id, 0) : quest.goals.distinct.count(:ace_id)
  end

  # Displays the number of participants on a quest with appropriate styling
  def quest_participants_badge(quest)
    count = quest_participants_count(quest)
    return if count.zero?

    content_tag(:span, class: 'quest-participants-badge') do
      icon("users", size: 18, class: "quest-participants-icon") +
      pluralize(count, 'participant')
    end
  end

  private

  def quest_card_highlights quest
    highlights = if quest.highlights.loaded?
      quest.highlights.select { |highlight| highlight.approved? && highlight.achievement&.approved? }
        .sort_by { |highlight| [ highlight.position || Float::INFINITY, highlight.id ] }
    else
      quest.highlights.approved.with_approved_achievement.ordered.includes(:achievement).to_a
    end
    highlights.partition(&:required?)
  end

  def quest_achievements_tooltip_content required, optional, summary
    sections = [ tag.p(summary, class: "quest-achievements-tooltip-heading") ]
    sections << quest_achievements_tooltip_list(required) if required.any?
    if optional.any?
      sections << tag.p(t("quests.card.optional_achievements", count: optional.size),
        class: "quest-achievements-tooltip-subheading")
      sections << quest_achievements_tooltip_list(optional)
    end
    safe_join sections
  end

  def quest_achievements_tooltip_list highlights
    tag.ul class: "quest-achievements-tooltip-list" do
      safe_join highlights.map { |highlight| quest_achievements_tooltip_item highlight.achievement }
    end
  end

  def quest_achievements_tooltip_item achievement
    detail = quest_achievement_tooltip_detail achievement
    tag.li class: "quest-achievements-tooltip-item" do
      tag.span(achievement.name, class: "quest-achievements-tooltip-name") +
      (detail ? tag.span(detail, class: "quest-achievements-tooltip-detail") : "".html_safe)
    end
  end

  def quest_achievement_tooltip_detail achievement
    if achievement.target_type == "Team"
      t "achievements.roster_levels.#{achievement.roster_level || 'mastery'}"
    elsif achievement.description.present? && achievement.description != achievement.name
      achievement.description
    end
  end
end
