# Claim-only Google proof: a second Google OmniAuth strategy on its own paths, so Devise's normal Google
# sign-in (Aces::OmniauthCallbacksController, Ace.from_google) never handles a claim. It forces an account
# chooser and a fresh login (max_age=0) and cannot have prompt overridden from the request.
Rails.application.config.middleware.use OmniAuth::Strategies::GoogleOauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
  name: :rizz_claim_google, request_path: "/auth/rizz/claim/google", callback_path: "/auth/rizz/claim/google/callback",
  scope: "openid,email,profile", access_type: "online", prompt: "select_account", authorize_params: { max_age: 0 },
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

# A session opened by Sign in with Rizz ends once its binding is disconnected or its Rizz epoch is behind the
# binding's (back-channel logout). Password and Google sign-ins just clear any stale marker.
Warden::Manager.after_set_user scope: :ace do |ace, auth, options|
  session = auth.request.session
  binding_id = session["rizz_binding_id"]
  next if binding_id.blank?

  if options[:event] == :authentication
    session.delete "rizz_binding_id"
    session.delete "rizz_session_epoch"
    next
  end

  status, epoch, ace_id = AceRizzBinding.where(id: binding_id).pick(:status, :rizz_session_epoch, :ace_id)
  unless status == "active" && ace_id == ace.id && epoch <= session["rizz_session_epoch"].to_i
    auth.logout :ace
    session.delete "rizz_binding_id"
    session.delete "rizz_session_epoch"
  end
end
