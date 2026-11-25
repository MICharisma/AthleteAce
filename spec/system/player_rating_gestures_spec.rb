require "rails_helper"

RSpec.describe "Player rating gestures", type: :system do
  let(:ace) { create(:ace) }
  let!(:player) do
    create(:player, first_name: "Aaron", last_name: "Judge", photo_urls: ["/missing-player-photo.png"],
      team: create(:team, territory: "New York", mascot: "Yankees", abbreviation: "NYY"))
  end
  let!(:familiarity) { create(:familiarity) }
  let!(:skill) { create(:skill) }

  before do
    driven_by :selenium_chrome_headless
    sign_in ace
  end

  def row_for spectrum
    find("#rating_spectrum_#{spectrum.id}_player_#{player.id}")
  end

  def expect_saved spectrum, value, average
    row = row_for spectrum
    expect(row).to have_css(".slider-value", text: value)
    expect(row).to have_css(".status-indicator", text: "Saved")
    expect(row.find(".rating-summary").text.squish).to eq(average)
    expect(row).to have_css("input:not([disabled])")
  end

  it "switches a held drag into fine adjustments and saves only on release" do
    original = create(:rating, ace: ace, rated: player, spectrum: familiarity, value: 43)
    visit player_path(player)
    row = row_for familiarity
    slider = row.find("input")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'})", slider)
    distance = ((slider.native.rect.width - 24) / 60).round
    browser = page.driver.browser
    browser.action.move_to(row.find(".rating-drag-handle").native).click_and_hold.perform
    browser.action.move_by(distance, 0).perform
    expect(row).to have_css(".slider-value", text: "53")
    browser.action.move_by(0, 40).perform
    expect(row).to have_css(".slider-value", text: "53")
    browser.action.move_by(distance, 0).perform
    expect(row).to have_css(".slider-value", text: "54")
    browser.action.move_by(0, -40).perform
    expect(row).to have_css(".slider-value", text: "54")
    expect(ace.ratings.count).to eq(1)
    browser.action.release.perform
    expect_saved familiarity, "54", "Aces average 54 1 rating"
    expect(original.reload).to be_archived
    expect(ace.ratings.count).to eq(2)
  end

  it "cancels an unrated drag with Escape and lets the user explicitly rate neutral" do
    visit player_path(player)
    row = row_for familiarity
    browser = page.driver.browser
    browser.action.move_to(row.find(".rating-drag-handle").native).click_and_hold.move_by(80, 0).perform
    expect(row).to have_content("Not saved yet")
    browser.action.send_keys(:escape).release.perform
    expect(row).to have_css(".slider-value", text: "Not rated")
    expect(row.find("input")["aria-valuetext"]).to eq("Not rated")
    expect(ace.ratings.count).to eq(0)
    within(row) { click_button "Rate neutral" }
    expect_saved familiarity, "0", "Aces average 0 1 rating"
    expect(ace.rating_for(player, familiarity).value).to eq(0)
  end

  it "supports touch precision while leaving the rest of the rating row scrollable" do
    create(:rating, ace: ace, rated: player, spectrum: familiarity, value: 43)
    phone_viewport
    visit player_path(player)
    row = row_for familiarity
    handle = row.find(".rating-drag-handle")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'})", handle)
    rect = page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", handle)
    x, y = rect.fetch("x") + 22, rect.fetch("y") + 22
    distance = ((row.find("input").native.rect.width - 24) / 60).round
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true)
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [{ x: x, y: y }])
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchMove", touchPoints: [{ x: x + distance, y: y }])
    expect(row).to have_css(".slider-value", text: "53")
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchMove", touchPoints: [{ x: x + distance, y: y + 40 }])
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchMove", touchPoints: [{ x: x + distance * 2, y: y + 40 }])
    expect(row).to have_css(".slider-value", text: "54")
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
    expect_saved familiarity, "54", "Aces average 54 1 rating"
    header = row_for(familiarity).find(".slider-header")
    header_rect = page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", header)
    scroll_before = page.evaluate_script("window.scrollY")
    x, y = header_rect.fetch("x") + 20, header_rect.fetch("y") + 5
    browser.execute_cdp("Input.synthesizeScrollGesture", x: x, y: y, yDistance: 90, speed: 250, gestureSourceType: "touch")
    Selenium::WebDriver::Wait.new(timeout: 2).until { page.evaluate_script("window.scrollY") < scroll_before }
    expect(ace.rating_for(player, familiarity).value).to eq(54)
  ensure
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end
end
