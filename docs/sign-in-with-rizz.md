# Sign in with Rizz: connecting and creating accounts

Everything except back-channel logout is live only while `RIZZ_SIGN_IN_ENABLED=1` and `RIZZ_OIDC_ISSUER`, `RIZZ_OIDC_CLIENT_ID` and `RIZZ_OIDC_CLIENT_SECRET` are present. With the flag off, every endpoint below returns 404. Run `rails db:migrate` before enabling the create flow.

## Connect an existing Ace (claim)

The Speaker POSTs an ES256 `rizz-claim-handoff+jwt` in the `handoff` field to `/auth/rizz/claim/start`. The browser proves it controls a local Ace with its password or the claim-only Google strategy, confirms both identities, and returns to the Speaker's callback with a single-use 60-second receipt. The Speaker spends the receipt at `POST /auth/rizz/claim/exchange`.

## Create an Ace from Rizz

`POST /auth/rizz/create/start` takes an ES256 `rizz-create-handoff+jwt` in the `handoff` field. It carries the claim handoff's claims (`jti`, `operation_id`, `speaker_label`, `callback_uri`, same issuer, audience and callback origin rules) plus:

| Claim | Meaning |
| --- | --- |
| `email` | The Speaker's verified Google email. Trimmed and lowercased here. |
| `display_name` | A suggested display name, at most 60 characters. May be empty. |

The token lives at most five minutes, and the stored handoff never outlives its signed `exp`. This is the only Create request that skips CSRF protection; the signed token is its credential. Like a claim handoff, it is stored server-side, single-use by `jti`, and bound to the browser by an encrypted HttpOnly cookie (`rizz_create_local`, `__Host-` under HTTPS). Claim and Create each honor only their own cookie and handoff intent.

1. **Existing email.** If an Ace already has the email, the handoff continues as an ordinary claim. The browser lands on the claim proof page with the claim cookie. Nothing is linked, no email is sent and the Ace is not changed. The same happens when the email appears between the form and its submission.
2. **New email.** The browser sees the verified email read-only and chooses a handle, a display name and a Devise-valid password with confirmation. Validation errors re-render the form without spending the handoff. A valid submission spends the handoff, stores the chosen handle, display name and a bcrypt digest on it, issues a receipt, and redirects to the Speaker's callback. No Ace exists yet, and the browser is not signed in.
3. **Exchange.** When the Speaker spends the receipt at `POST /auth/rizz/claim/exchange`, one transaction builds the confirmed Ace from the handoff's email, handle, display name and digest, binds it to the Rizz subject and spends the receipt. The Ace therefore exists only after the Speaker has checked its own browser binding. The response is the claim exchange's `{ ok, local_handle, has_independent_recovery: true }`. The new Ace can sign in to AthleteAce with its email and password without Rizz.

If the email or handle was taken after onboarding, or the Rizz subject is bound elsewhere, the exchange creates nothing and answers 409. The body is `{"error":"email_taken"}` when the email now belongs to an Ace, and `{"error":"conflict"}` otherwise.

## Staged password digests

The bcrypt digest is held on the handoff only until the receipt is spent or fails. A successful exchange and any conflicting exchange clear it. `RizzClaimHandoff.purge_spent_drafts!` clears digests of handoffs spent more than 60 seconds ago. It runs when a handoff starts and every five minutes from `config/recurring.yml` in production. The digest is never logged, and the `handoff`, `receipt`, `email` and password parameters are filtered from logs.
