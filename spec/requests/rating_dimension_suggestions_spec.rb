require "rails_helper"

RSpec.describe "Rating dimension suggestions", type: :request do
  let(:ace) { create(:ace) }
  let(:player) { create(:player) }
  let!(:skill) { create(:skill) }
  let!(:familiarity) { create(:familiarity) }
  let!(:answered) { create(:spectrum, name: "Affinity") }

  around do |example|
    previous = Rails.configuration.x.shared_ratings.suggestion_provider
    Rails.configuration.x.shared_ratings.suggestion_provider = ->(**) { [] }
    example.run
  ensure
    Rails.configuration.x.shared_ratings.suggestion_provider = previous
  end

  it "ranks only visible unanswered dimensions with user choice counts and creates no ratings" do
    sign_in ace
    create(:rating, ace: ace, rated: player, spectrum: answered, value: 0)
    create(:rating, ace: ace, rated: create(:player), spectrum: skill, value: -84)
    hidden = create(:spectrum, moderation_status: "hidden")
    Rails.configuration.x.shared_ratings.suggestion_provider = lambda do |**input|
      keys = input[:candidates].map { |candidate| candidate[:key] }
      expect(keys).to contain_exactly(skill.rating_dimension.key, familiarity.rating_dimension.key)
      expect(input[:preferences]).to eq([{ key: skill.rating_dimension.key, times_chosen: 1 }])
      # Compare values, not JSON text: UUIDv7 keys can contain "-84".
      values = ->(object) { object.is_a?(Hash) ? object.values.flat_map(&values) : object.is_a?(Array) ? object.flat_map(&values) : [ object ] }
      expect(values.call(input)).not_to include(ace.email, -84)
      [hidden.rating_dimension.key, skill.rating_dimension.key, skill.rating_dimension.key]
    end

    expect do
      post suggest_dimensions_player_ratings_path(player)
    end.not_to change(Rating, :count)
    expect(response.parsed_body).to eq("suggestions" => [
      { "key" => skill.rating_dimension.key, "label" => "Skill" },
      { "key" => familiarity.rating_dimension.key, "label" => "Familiarity" }
    ], "source" => "ai")
  end

  it "rechecks answered dimensions after the provider responds" do
    sign_in ace
    Rails.configuration.x.shared_ratings.suggestion_provider = lambda do |**|
      create(:rating, ace: ace, rated: player, spectrum: skill, value: 100)
      [skill.rating_dimension.key]
    end
    post suggest_dimensions_player_ratings_path(player)
    expect(response.parsed_body["suggestions"].map { |item| item["key"] }).not_to include(skill.rating_dimension.key)
  end

  it "uses the configured provider when the app has no override" do
    sign_in ace
    Rails.configuration.x.shared_ratings.suggestion_provider = nil
    allow(SharedRatings::LLMProvider).to receive(:from_env).and_return(->(**) { [skill.rating_dimension.key] })
    post suggest_dimensions_player_ratings_path(player)
    expect(response.parsed_body["source"]).to eq("ai")
    expect(response.parsed_body["suggestions"].first["key"]).to eq(skill.rating_dimension.key)
  end

  it "requires sign-in and appends an authorized dimension through the existing rating row" do
    post suggest_dimensions_player_ratings_path(player)
    expect(response).to redirect_to(new_ace_session_path)
    sign_in ace
    expect do
      get dimension_player_ratings_path(player), params: { spectrum_id: skill.id }
    end.not_to change(Rating, :count)
    expect(response.body).to include('action="append"', "Skill", "Not rated")
    hidden = create(:spectrum, moderation_status: "hidden")
    get dimension_player_ratings_path(player), params: { spectrum_id: hidden.id }
    expect(response).to have_http_status(:not_found)
  end
end
