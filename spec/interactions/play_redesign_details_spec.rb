require "rails_helper"

RSpec.describe "Play detail pages" do

  it "opens the player's public shout-out list from the Play profile" do
    author = create :ace, display_name: "Avery Morgan"
    reviewer = create :ace, moderator: true
    player = create :player, first_name: "Jordan", last_name: "Reyes"
    buy_credit author
    messages = [ "Always finds the open teammate.", "A calm finish under pressure.", "The extra pass made that play.", "Great energy throughout the game." ]
    messages.each do |message|
      post = submit_credit(ace: author, target: player, message: message, bid: 1)
      review_post(post, action: "approve", reviewer: reviewer)
    end
    visit player_path(player, side: "play")
    expect(page).to have_css(".player-shout-outs .shout-out-card", count: 3)
    expect(page).to have_css('body[data-side="play"]')
    click_link "All player shout-outs"
    expect(page).to have_current_path(player_shout_outs_path(player))
    expect(page).to have_css('body[data-side="feed"]')
    expect(page).to have_css(".shout-out-card", count: 4)
    messages.each { |message| expect(page).to have_content(message) }
  end

  it "shows approval attribution and recorded versus current quest progress" do
    ace = create :ace
    team = create :team
    players = [ [ "Jordan", "Reyes" ], [ "María", "Calderón" ] ].map do |first_name, last_name|
      create :player, team: team, first_name: first_name, last_name: last_name
    end
    group = PlayerGroup.create! name: "Harbor backcourt", players: players
    quest = create :quest, name: "Know the Harbor backcourt"
    achievement = create :achievement, target: team, name: "Learn the team's players"
    create :highlight, quest: quest, achievement: achievement
    goal = create :goal, ace: ace, quest: quest
    round = GameRoundSetup.new(game_type: "name_ciphers", player_group_id: group.id).start!(ace)
    round.questions.each_with_index do |question, position|
      round.answer!(at: position, choice_id: question.fetch("target_id"))
      round.advance!(at: position)
    end
    sign_in ace
    visit quest_path(quest)
    expect(page).to have_css(".quest-approval time")
    visit summary_game_round_path(round)
    expect(page).to have_css(".round-learning-progress", text: quest.name)
    expect(page).to have_css('[data-quest-progress-point="before"]', text: "0% · 0 of 1")
    expect(page).to have_css('[data-quest-progress-point="after"]', text: "100% · 1 of 1")
    expect(page).to have_content("2 of 2 players answered correctly since adoption")
    expect(goal.reload.status).to eq("completed")
  end
end
