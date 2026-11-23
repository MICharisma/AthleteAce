require "rails_helper"

RSpec.describe "Account page layout", type: :system do
  before { phone_viewport }

  it "fits sign-in, sign-up and password reset on a phone" do
    visit new_ace_session_path
    expect(page).to have_css("h1", text: /sign in/i)
    expect_no_horizontal_overflow
    visit new_ace_registration_path
    expect(page).to have_field("Confirm password")
    expect_no_horizontal_overflow
    visit new_ace_password_path
    expect(page).to have_button("Send reset instructions")
    expect_no_horizontal_overflow
  end
end
