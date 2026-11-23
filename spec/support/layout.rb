# System specs exist for layout: what only a real browser's CSS can show.
# Behavior belongs in interaction specs (spec/interactions).
module LayoutHelpers
  def phone_viewport
    page.driver.browser.execute_cdp "Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: false
  end

  def expect_no_horizontal_overflow
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end

  def rect(selector)
    page.evaluate_script("document.querySelector(arguments[0]).getBoundingClientRect().toJSON()", selector)
  end
end

RSpec.configure do |config|
  config.include LayoutHelpers, type: :system
  config.after(type: :system) do
    page.driver.browser.execute_cdp "Emulation.clearDeviceMetricsOverride" if page.driver.browser.respond_to?(:execute_cdp)
  end
end
