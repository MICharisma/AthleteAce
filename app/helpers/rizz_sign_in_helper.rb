module RizzSignInHelper
  def rizz_sign_in_button
    return unless RizzSignIn.enabled?

    button_to t("authentication.sign_in_with_rizz"), rizz_auth_path, method: :post, class: "game-button",
      form: { class: "rizz-sign-in-form", data: { turbo: false, turbo_frame: "_top" } }
  end
end
