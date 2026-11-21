# Sign in with Rizz, the claim handoff, and back-channel logout. Present only while RizzSignIn is enabled.
# POST /auth/rizz/claim/google is the claim-only Google OmniAuth request path (see config/initializers/rizz_sign_in.rb).
Rails.application.routes.draw do
  constraints ->(_request) { RizzSignIn.enabled? } do
    post "auth/rizz", to: "rizz_auth/sessions#create", as: :rizz_auth
    get "auth/rizz/callback", to: "rizz_auth/sessions#callback", as: :rizz_auth_callback
    match "auth/rizz/claim/start", to: "rizz_auth/claims#start", via: %i[get post], as: :rizz_claim_start
    get "auth/rizz/claim/prove", to: "rizz_auth/claims#prove", as: :rizz_claim_prove
    post "auth/rizz/claim/verify_password", to: "rizz_auth/claims#verify_password", as: :rizz_claim_verify_password
    get "auth/rizz/claim/google/callback", to: "rizz_auth/claims#google_callback", as: :rizz_claim_google_callback
    get "auth/rizz/claim/confirm", to: "rizz_auth/claims#confirm", as: :rizz_claim_confirm
    post "auth/rizz/claim/confirm", to: "rizz_auth/claims#connect"
    post "auth/rizz/claim/cancel", to: "rizz_auth/claims#cancel", as: :rizz_claim_cancel
    post "auth/rizz/claim/exchange", to: "rizz_auth/exchanges#create"
    post "auth/rizz/backchannel_logout", to: "rizz_auth/backchannel_logouts#create"
  end
end
