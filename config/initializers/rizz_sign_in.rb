# Claim-only Google proof: a second Google OmniAuth strategy on its own paths, so Devise's normal Google
# sign-in (Aces::OmniauthCallbacksController, Ace.from_google) never handles a claim. Consumer Google OAuth
# does not support max_age=0 or reliably emit auth_time, so we enforce an explicit account chooser
# (prompt=select_account) that cannot be overridden from the request, and pair it with fresh ID token
# issuance (iat), browser-bound __Host-rizz_claim, strict google_uid lookup, and dual-identity confirmation.
module OmniAuth
  module Strategies
    # Inert (never intercepts its paths) unless Sign in with Rizz and Google sign-in are both enabled.
    class RizzClaimGoogle < GoogleOauth2
      def on_path?(path)
        RizzSignIn.enabled? && Rails.application.config.x.google_oauth.enabled && super
      end
    end
  end
end

Rails.application.config.middleware.use OmniAuth::Strategies::RizzClaimGoogle, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
  name: "rizz_claim_google", request_path: "/auth/rizz/claim/google", callback_path: "/auth/rizz/claim/google/callback",
  scope: "openid,email,profile", access_type: "online", prompt: "select_account",
  overridable_authorize_options: []

Rails.application.config.after_initialize do
  devise_failure = OmniAuth.config.on_failure
  OmniAuth.config.on_failure = proc do |env|
    if env["PATH_INFO"].to_s.start_with?("/auth/rizz/claim/google")
      RizzAuth::ClaimsController.action(:google_failure).call(env)
    else
      devise_failure.call(env)
    end
  end
end

# A session opened by Sign in with Rizz ends once the feature is switched off, its binding is disconnected, or
# its Rizz epoch is behind the binding's (back-channel logout). The marker is written only by the Rizz callback
# (an :authentication event); any other sign-in (password, Google, remember-me) clears it first, so a stale
# marker can never log a different sign-in out.
Warden::Manager.after_set_user scope: :ace do |ace, auth, options|
  session = auth.request.session
  if options[:event] != :fetch
    session.delete "rizz_binding_id"
    session.delete "rizz_session_epoch"
    next
  end

  binding_id = session["rizz_binding_id"]
  next if binding_id.blank?

  status, epoch, ace_id = AceRizzBinding.where(id: binding_id).pick(:status, :rizz_session_epoch, :ace_id)
  unless RizzSignIn.enabled? && status == "active" && ace_id == ace.id && epoch <= session["rizz_session_epoch"].to_i
    auth.logout :ace
    session.delete "rizz_binding_id"
    session.delete "rizz_session_epoch"
  end
end
