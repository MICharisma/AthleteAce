module GoogleSignInHelper
  def google_sign_in_button
    return unless Rails.application.config.x.google_oauth.enabled

    button_to ace_google_oauth2_omniauth_authorize_path, method: :post,
      class: "google-sign-in", aria: { label: t("authentication.google_label", site: "AthleteAce") },
      form: { class: "google-sign-in-form", data: { turbo: false, turbo_frame: "_top" } } do
      safe_join [
        image_tag("/google-g.png", alt: "", width: 18, height: 18),
        tag.span(t("authentication.continue_with_google"), class: "google-sign-in-label"),
        image_tag("/google-sign-in-site.svg", alt: "", width: 20, height: 20, class: "google-sign-in-site")
      ]
    end
  end
end
