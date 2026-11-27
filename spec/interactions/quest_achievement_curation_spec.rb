require "rails_helper"

RSpec.describe "Quest and achievement curation" do
  let(:ace) { create(:ace) }
  let(:team) { create(:team, territory: "Boston", mascot: "Celtics", abbreviation: "BOS") }
  let!(:achievement) { create(:achievement, name: "Learn the Celtics", target: team, roster_level: "fluency") }
  let!(:quest) { create(:quest, name: "Eastern Tour", description: "Know the eastern rosters.") }
  let!(:highlight) { create(:highlight, quest: quest, achievement: achievement, required: true) }
  let!(:list) { TierLists::List.create!(name: "My Study Plan", owner: ace, privacy: :published) }

  before do
    sign_in ace
  end

  it "engages with and adds a Quest to the active playbook in place" do
    visit quest_path(quest)

    find("#action_bar_quest_#{quest.id} summary").click
    within("#action_bar_quest_#{quest.id}") do
      click_button "Save"
      expect(page).to have_button("Saved")
      click_button "Follow"
      expect(page).to have_button("Following")
    end
    expect(ace.engagements.where(engageable: quest).pluck(:kind)).to match_array(%w[bookmark follow])

    find("header .playbook-item-action").click
    expect(page).to have_css("header .playbook-item-action[data-playbook-state='added']", text: "In playbook")
    expect(list.listed_items.reload.map(&:content)).to include(quest)
  end

  it "engages with and adds an Achievement to the active playbook in place" do
    visit achievement_path(achievement)

    find("#action_bar_achievement_#{achievement.id} summary").click
    within("#action_bar_achievement_#{achievement.id}") do
      click_button "Favorite"
      expect(page).to have_button("Favorited")
    end
    expect(ace.engagements.favorite.where(engageable: achievement)).to exist

    find("header .playbook-item-action").click
    expect(page).to have_css("header .playbook-item-action[data-playbook-state='added']", text: "In playbook")
    expect(list.listed_items.reload.map(&:content)).to include(achievement)
  end
end
