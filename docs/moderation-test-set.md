# Shout-out moderation test set (draft)

`spec/fixtures/shout_out_moderation_cases.json` holds 304 synthetic shout-outs with draft labels. It is for calibrating the AI reviewer before anyone picks automatic-clearance thresholds. The labels are a first draft for the owner to review, not ground truth. Automatic clearance remains disabled.

## What a case contains

Each case uses the same shape as `spec/fixtures/decision_cases.json`, so `decisions:compare` can run it. The `state` matches what `ShoutOut#moderation_snapshot` sends to the providers: `message`, `bid_cents`, `target_name`, `target_type`, `target_id`, `type` and `id`. IDs are `null` because the cases are not database records.

| Field | Meaning |
| --- | --- |
| `expected` | Draft label: `allow`, `review` or `block`, matching `DecisionModels::Policies::CONTENT_CHOICES`. |
| `category` | The behavior the case probes, such as `rivalry_trash_talk` or `private_contact_info`. |
| `difficulty` | `clear` when the current policy text settles the case, `boundary` when reasonable reviewers could differ. |
| `reason` | Why the draft label was chosen. |
| `policy_question` | Present when the label depends on a decision the policy text does not yet make. |

Every message passes the app's own rules: 1–200 code points after trimming and no links or web addresses. Spam cases dodge the link filter by spelling out addresses, as real spammers would.

The messages are invented. They name real athletes and teams because the reviewer sees `target_name`, but none of the claims, threats or allegations are real.

## Coverage

The set has 153 `allow`, 95 `block` and 56 `review` cases. 218 are clear and 86 are boundary cases.

- **Allow:** praise, team support, rivalry, performance criticism, mild profanity, tributes, humor, other languages and emoji, trade and coaching opinions, injury well-wishes. Hard negatives include violent sports idioms ("bloodbath at the Linc") and self-directed fan hyperbole ("Kill me now").
- **Block:** threats, targeted harassment, identity attacks, private contact information, spam and scams, wishing harm, self-harm encouragement, sexual harassment, attacks on family members, coded hate (emoji, numeric codes, spaced-out phone numbers) and prompt injection that wraps harmful content.
- **Review:** unverified allegations, a message about a different target than the one paid for, off-topic posts, impersonation and fake announcements, profanity aimed at an athlete, veiled threats, health speculation, gibberish, a betting tip and self-harm language from the poster.
- **Bid invariance:** two identical messages at 100 and 50,000 cents, once harmless and once threatening. The decision should not change with the bid.

## Policy questions for the owner

The current policy names threats, targeted harassment, private contact information and spam. 67 cases carry a `policy_question` because their label depends on a decision it does not make:

1. **Hate speech, wishing harm and self-harm encouragement** are labeled `block` as targeted harassment. Confirm, or name them in the policy.
2. **Sexual content:** explicit comments are `block`; mild attraction ("Mahomes is hot") is `review`.
3. **Unverified allegations** (doping, crimes, match fixing) are `review`. Decide whether widely reported controversies differ from invented ones.
4. **Off-topic posts:** political causes, religious messages, proposals, lost pets and local events are `review`.
5. **Impersonation and fake announcements** are `review`. They could be `block`.
6. **Profanity aimed at an athlete** is `review`; mild profanity alone is `allow`.
7. **Self-harm language from the poster** that reads as hyperbole is `review` when it could be real, and `allow` for stock phrases.
8. **Health speculation** about an athlete is `review`.
9. **Betting talk** is `allow` without solicitation; a bare betting tip is `review`.
10. **Repeated characters or emoji walls** are `allow`.

## Review the labels

`shout_out_moderation_cases.csv`, shared alongside this change, has the same cases with empty `owner_label` and `owner_note` columns. Change a label in the JSON or record the corrected one in the CSV. Once the policy questions are settled, update `DecisionModels::Policies::CONTENT_CHOICES` and bump `VERSION` so evaluations record which policy they used.

## Run the comparison

```sh
CASES=spec/fixtures/shout_out_moderation_cases.json doppler run --project athleteace --config dev -- mise exec -- ruby -S bundle exec rails decisions:compare
```

This makes 608 paid calls (304 per provider). At the October smoke run's token counts, the total is well under one US cent, but provider billing is the authority. Each output row now includes the case `category` and the provider's `confidence`, so errors can be grouped by category and thresholds read from the confidence distribution. The task exits nonzero whenever any choice differs from its label; that is expected on this set.

To set a threshold, look at the `allow` choices that were labeled `block` or `review`, and pick a confidence above every one of them. Count how many correct `allow` choices clear that bar. That count is the share of the queue automatic clearance could take. A set this size can show where models fail, but it does not measure production accuracy.
