require "rails_helper"

RSpec.describe "Admin player histories", type: :request do
  let(:player) { create(:player, first_name: "Jordan", last_name: "Reed") }

  before { sign_in create(:ace, :admin) }

  it "renders each history tab" do
    Admin::PlayerHistoriesController::TABS.each do |tab|
      get admin_player_history_path(player, tab: tab)
      expect(response).to have_http_status(:ok), tab
    end
  end

  it "refuses a tab that isn't one of the history tabs" do
    get admin_player_history_path(player, tab: "../../layouts/application")
    expect(response).to have_http_status(:bad_request)
  end

  it "renders every history tab" do
    sign_in admin
    Admin::PlayerHistoriesController::TABS.each do |tab|
      get admin_player_history_path(player, tab: tab)
      expect(response).to have_http_status(:ok), tab
    end
  end

  it "refuses a tab that isn't one of the history tabs" do
    sign_in admin
    get admin_player_history_path(player, tab: "../../layouts/application")
    expect(response).to have_http_status(:bad_request)
  end
end
