require "rails_helper"

RSpec.describe "Player profiles and rating controls" do
  let(:ace) { create(:ace) }
  let!(:player) do
    create(:player, first_name: "Aaron", last_name: "Judge", photo_urls: ["/missing-player-photo.png"],
      team: create(:team, territory: "New York", mascot: "Yankees", abbreviation: "NYY"))
  end
  let!(:familiarity) { create(:familiarity) }
  let!(:skill) { create(:skill) }

  before do
    sign_in ace
  end

  def row_for spectrum
    find("#rating_spectrum_#{spectrum.id}_player_#{player.id}")
  end

  def expect_saved spectrum, value, average
    row = row_for spectrum
    expect(row).to have_css(".slider-value", text: value)
    expect(row).to have_css(".status-indicator", text: "Saved")
    expect(row).to have_css(".rating-summary", text: average)
    expect(row).to have_css("input:not([disabled])")
  end

  it "uses the standard range in the standalone form and explains neutral separately from the endpoints" do
    visit new_player_rating_path(player, spectrum_id: familiarity.id)
    input = find('input[type="range"]')
    expect(input["min"]).to eq("-100")
    expect(input["max"]).to eq("500")
    expect(input["step"]).to eq("1")
    expect(input.value).to eq("0")
    expect(page).to have_content("Your Rating (-100 to +500)")

    visit spectrum_path(familiarity)
    expect(page).to have_content("Neutral: 0")
    expect(page).to have_content("-100")
    expect(page).to have_content("+500")
  end

  it "explains the sign-in requirement when a visitor clicks or uses the keyboard on a slider" do
    sign_out ace
    create(:rating, rated: player, spectrum: familiarity, value: 80)
    visit player_path(player)

    row = row_for familiarity
    expect(row).to have_css(".rating-sign-in-link.hidden")
    row.find("button[aria-label='Sign in to rate Familiarity']").click
    expect(row).to have_content("You need to sign in to rate.")
    expect(row).to have_css(".rating-sign-in-link:not(.hidden)[href='#{new_ace_session_path}']")
    expect(row).to have_css(".slider-value", text: "Not rated")
    expect(row).to have_content("Aces average +80 · 1 rating")
    expect(row.find("input")).to be_disabled
    expect(row.find("input").value).to eq("0")
    expect(player.ratings.count).to eq(1)

    row_for(skill).find("button[aria-label='Sign in to rate Skill']").send_keys :enter
    expect(row_for(skill)).to have_content("You need to sign in to rate.")
    within(row_for(skill)) { click_link "Sign in" }
    expect(page).to have_current_path(new_ace_session_path)
  end

  it "preserves existing exact values and saves keyboard changes with coarse and fine precision" do
    original = create(:rating, ace: ace, rated: player, spectrum: familiarity, value: 43)
    create(:rating, rated: player, spectrum: familiarity, value: 17)
    visit player_path(player)

    click_button "Fine"
    expect(row_for(familiarity).find("input").value).to eq("43")
    expect(ace.ratings.count).to eq(1)
    expect(row_for(familiarity)).not_to have_content("Saved")
    click_button "Coarse"
    row_for(familiarity).find("input").send_keys :arrow_right
    expect_saved familiarity, "+53", "Aces average +35 · 2 ratings"
    expect(original.reload).to be_archived
    expect(page).to have_css("#rating_spectrum_#{familiarity.id}_player_#{player.id} input:focus")

    click_button "Fine"
    row_for(familiarity).find("input").send_keys :arrow_left
    expect_saved familiarity, "+52", "Aces average +35 · 2 ratings"
    expect(ace.rating_for(player, familiarity).value).to eq(52)
    expect(page).to have_css(".precision-control button[aria-pressed=true]", text: "Fine")
  end

  it "snaps pointer input to the chosen increments and offers a working retry after a failed save" do
    visit player_path(player)
    # Exercise a dropped request without changing the persisted data.
    page.execute_script <<~JS
      const originalFetch = window.fetch;
      window.fetch = (...args) => {
        if (args[1]?.method === 'POST') {
          window.fetch = originalFetch;
          return Promise.resolve(new Response('', { status: 503 }));
        }
        return originalFetch(...args);
      };
      const slider = document.querySelector('#rating_spectrum_#{familiarity.id}_player_#{player.id} input');
      slider.value = 26.5;
      slider.dispatchEvent(new Event('input', { bubbles: true }));
      slider.dispatchEvent(new Event('change', { bubbles: true }));
    JS
    row = row_for familiarity
    expect(row).to have_css(".slider-value", text: "+30")
    expect(row).to have_content("Couldn’t save your rating.")
    expect(ace.ratings.active.count).to eq(0)
    within(row) { click_button "Retry" }
    expect_saved familiarity, "+30", "Aces average +30 · 1 rating"

    click_button "Fine"
    page.execute_script <<~JS
      const slider = document.querySelector('#rating_spectrum_#{familiarity.id}_player_#{player.id} input');
      slider.value = 26.5;
      slider.dispatchEvent(new Event('input', { bubbles: true }));
      slider.dispatchEvent(new Event('change', { bubbles: true }));
    JS
    expect_saved familiarity, "+27", "Aces average +27 · 1 rating"
  end

  it "reuses the shared controls when the browse spectrum picker changes traits" do
    create(:rating, ace: ace, rated: player, spectrum: skill, value: 20)
    create(:rating, rated: player, spectrum: skill, value: 40)
    visit players_path
    click_button "Fine"
    find(".spectrum-picker-toggle").click
    within ".spectrum-picker-panel" do
      click_button "Skill"
    end
    expect(page).to have_css(".slider-label", text: "Skill", count: 1)
    expect(page).not_to have_css(".slider-label", text: "Familiarity")
    expect(row_for(skill)).to have_css(".slider-value", text: "+20")
    expect(row_for(skill)).to have_content("Aces average +30 · 2 ratings")
    row_for(skill).find("input").send_keys :arrow_right
    expect_saved skill, "+21", "Aces average +31 · 2 ratings"

    within ".spectrum-picker-panel" do
      check "Multiple"
      click_button "Familiarity"
    end
    expect(page).to have_css(".rating-slider-instance", count: 2)
    within ".spectrum-picker-panel" do
      click_button "Skill"
      click_button "Familiarity"
    end
    expect(page).to have_content("Select a spectrum to see rating sliders.")
    expect(page).not_to have_css(".rating-slider-instance")
  end

  it "switches between the jersey fallback and a loaded photo" do
    player.team.update! primary_color: "#1450BE", abbreviation: "ACE"
    visit player_path(player)
    find(".profile-portrait img", visible: :all).execute_script("this.dispatchEvent(new Event('error'))")

    initials = player.name.split.map { |word| word[0] }.first(3).join.upcase
    expect(page).to have_css(".profile-portrait[data-image-state=fallback] .jersey-initials", text: initials)
    expect(page).to have_css(".profile-photo.hidden", visible: :all)

    JerseyNumberAssignment.create!(player: player, team: player.team, number: "00", start_date: Date.current - 1.year)
    visit player_path(player)
    expect(page).to have_css(".profile-jersey .jersey-number", text: "00")
    expect(page).not_to have_css(".profile-jersey .jersey-initials")

    player.update! photo_urls: ["/icon.png"]
    visit player_path(player)
    find(".profile-portrait img", visible: :all).execute_script("this.dispatchEvent(new Event('load'))")
    expect(page).to have_css(".profile-portrait[data-image-state=loaded] .profile-photo")
    expect(page).to have_css(".profile-jersey.hidden", visible: :all)
  end

  it "suggests dimensions without replacing an existing draft or rating for the user" do
    create(:rating, ace: ace, rated: player, spectrum: familiarity, value: 43)
    Rails.configuration.x.shared_ratings.suggestion_provider = ->(**) { [skill.rating_dimension.key] }
    visit player_path(player)
    page.execute_script <<~JS
      window.existingRatingInput = document.querySelector('#rating_spectrum_#{familiarity.id}_player_#{player.id} input');
      window.existingRatingInput.value = 40;
      window.existingRatingInput.dispatchEvent(new Event('input', { bubbles: true }));
    JS
    within ".dimension-picker" do
      click_button "Suggest for me"
      expect(page).to have_content("AI suggestions")
      within(".dimension-suggestions") { click_button "Skill" }
    end
    expect(page).to have_css("#rating_spectrum_#{skill.id}_player_#{player.id} input:focus")
    expect(row_for(familiarity)).to have_css(".slider-value", text: "+40")
    expect(page.evaluate_script("window.existingRatingInput === document.querySelector('#rating_spectrum_#{familiarity.id}_player_#{player.id} input')")).to be(true)
    expect(ace.ratings.count).to eq(1)
    expect(ace.rating_for(player, familiarity).value).to eq(43)
    row_for(skill).find("input").send_keys :arrow_right
    expect_saved skill, "+10", "Aces average +10 · 1 rating"
  ensure
    Rails.configuration.x.shared_ratings.suggestion_provider = nil
  end

  it "opens an additional browse dimension without replacing the current editor" do
    visit players_path
    expect(page).not_to have_css(".slider-label", text: "Skill", exact_text: true)
    page.execute_script <<~JS
      window.existingRatingInput = document.querySelector('#rating_spectrum_#{familiarity.id}_player_#{player.id} input');
      window.existingRatingInput.value = 40;
      window.existingRatingInput.dispatchEvent(new Event('input', { bubbles: true }));
    JS
    within(".rating-slider-group-container .dimension-picker") { select "Skill", from: "Choose a dimension" }
    expect(row_for(skill)).to have_css("input:focus")
    expect(page).to have_css(".rating-slider-instance", count: 2)
    expect(row_for(familiarity)).to have_css(".slider-value", text: "+40")
    expect(page.evaluate_script("window.existingRatingInput === document.querySelector('#rating_spectrum_#{familiarity.id}_player_#{player.id} input')")).to be(true)
    expect(ace.ratings.count).to eq(0)
  end
end
