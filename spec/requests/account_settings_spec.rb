require "rails_helper"

RSpec.describe "Account settings", type: :request do
  it "renders the styled account settings card and danger section for a signed-in ace" do
    ace = create(:ace)
    sign_in ace

    get edit_ace_registration_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    card = page.at_css("section.account-card")
    expect(card).to be_present
    expect(card.text).to include("Account settings")
    expect(card.at_css("form.account-form[action='#{ace_registration_path}']")).to be_present

    danger = card.at_css("section.account-danger")
    expect(danger).to be_present
    expect(danger.at_css("form[action='#{ace_registration_path}'] button.account-danger-button")&.text).to include("Cancel my account")
  end

  it "redirects signed-out visitors to sign in" do
    get edit_ace_registration_path

    expect(response).to redirect_to(new_ace_session_path)
  end
end
