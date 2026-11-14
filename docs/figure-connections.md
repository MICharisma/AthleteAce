# Figure connections: businesses, practices, statements and evidence

Figures can carry sourced connections to businesses, wellness or skill practices, and their own words. Each connection is a typed claim with a stable entity code. Evidence lives in `Attestation` records, not in a claim-level `source` column. This is the model layer from AA-33, AA-104, AA-34, AA-215 and AA-222, with admin review and publication from AA-217 and public pages from AA-218.

Dates on every claim use the [partial-date rules](figures-and-staff.md#appointments): `YYYY`, `YYYY-MM`, `YYYY-MM-DD` or null for unknown. The `PartialDates` concern validates them and rejects a range whose start falls entirely after its end.

## Businesses

`Business` is separate from `Organization`, which keeps its sports-side meaning. A Business can be a company, a foundation, a school or a similar institution, and the name doesn't imply for-profit status. It has a name, an optional URL, `founded_year`, an optional description, an entity code, and `source`/`details` metadata. Same-name businesses never merge. If a source separates a brand from its legal owner, the two become separately coded Businesses with no inferred hierarchy.

`FigureBusinessRelationship` links one Figure to one Business with exactly one `predicate`:

| Predicate | Meaning |
| --- | --- |
| `founded` | A founding event. It has no end date, can't be reported current, and stays true after the founder exits. |
| `owns` | Ownership over a date range. |
| `invests_in` | A sourced investment. `vehicle_name` records a fund or holding company when the source names one. |
| `endorses`, `promotes`, `sponsored_by` | Commercial promotion. These are the only predicates that record compensation. |

Several predicates can link the same Figure and Business, each with its own dates and evidence. A sponsorship never implies a promotion, ownership or investment.

`compensation` is `documented_paid`, `documented_unpaid` or `unknown`, and defaults to `unknown`. A missing payment disclosure stays unknown, never unpaid. `compensation_description` keeps the source's own wording. Amounts, percentages and valuations are out of scope.

## Temporal state

Business and practice relationships share the `TemporalClaim` concern. `temporal_state` is one of:

| State | Meaning |
| --- | --- |
| `reported_current` | Requires `as_of_date` and no end date. |
| `historical` | The relationship has ended. |
| `planned` | Can't have an end date. |
| `unknown` | The default. |

A missing end date never means current.

## Practices and protocols

`Practice` is a broad activity or meaning, such as prayer, gratitude or meditation. `Protocol` is a concrete routine, such as a morning walk, with an optional `routine` description. Neither is a parent of the other, and same-name records never merge.

`FigurePracticeRelationship` is one Figure's sourced connection, with these predicates:

| Predicate | Meaning |
| --- | --- |
| `participates_in` | The Figure does it. |
| `recommends` | The Figure recommends it. |
| `teaches` | The Figure teaches it. |
| `endorses` | The Figure endorses it. Describing your own routine isn't an endorsement. |

The relationship has an optional Protocol, the Figure's own wording in `interpretation`, dates and context. `PracticeConnection` rows name the Practices this Figure connects in this claim. Each Practice appears once per claim, and `practices` sorts by name and then code. One athlete's morning walk can name prayer and gratitude while another's names exercise. Neither interpretation spreads to other claims.

A claim may name only Practices or only a Protocol. `targeted?` is false when it names neither, and such a claim can't be published.

`PracticeReview` is unrelated: it is Play's spaced study.

## Attributed statements

`AttributedStatement` belongs to the Figure it is about. `attribution_kind` is one of:

| Kind | Meaning |
| --- | --- |
| `direct_quote` | The Figure is the speaker. |
| `attributed_paraphrase` | A paraphrase of the Figure, labeled as one. |
| `self_stated_value` | A value stated in the Figure's own words. |
| `observer_characterization` | Someone else describing the Figure. Requires `observer` (another Figure) or `observer_name`. |

Other kinds can't have an observer. The optional links must concern the same Figure:

- `figure_practice_relationship` brings in that claim's Protocol and Practice context.
- `staff_tenure` records the role the Figure held at the time, so a later move doesn't reattribute the text.

`Topic` is a short, editor-managed list with unique names. A statement has at most one primary Topic. A Topic organizes statements and never establishes a belief.

Fan ratings, the Wisdom spectrum and fan posts never populate statements.

## Attestations

`Attestation` supports exactly one claim. `claim` is a polymorphic reference limited to `FigureBusinessRelationship`, `FigurePracticeRelationship` and `AttributedStatement`, and a database check enforces the same limit. `content_form` sets which payload is required:

| Form | Requires |
| --- | --- |
| `text` | `body` |
| `link` | `url` |
| `image` or `video` | `media_url` or `url` |

Optional fields:

| Field | Holds |
| --- | --- |
| `excerpt` | The supporting passage. |
| `locator` | A paragraph, page or timestamp. |
| `source_title`, `publisher` | Where the material was published. |
| `published_on` | A partial date. |
| `captured_at` | When it was captured. |
| `context` | Why the material supports the claim. |

Four parties stay separate:

- the claim's Figure
- the material's original author: `author` when a catalog Figure exists, otherwise the literal `author_name`
- the publisher
- the Ace who entered it (`entered_by`)

Unknown authors and dates stay null. A URL doesn't identify an Attestation: one page can support several claims through separately coded Attestations. `complete?` requires a traceable source (a URL, a media URL or a source title) and context. Phase one stores text and URLs only, with no file uploads.

## Review and publication

Every claim starts pending, whether an admin or the importer created it. Only `published` (approved) claims, and `Attestation.published` evidence, are public. Phase one is trusted admin publication: any active admin can publish, including a claim they entered. Moderators and fans can't. Community submissions (AA-219) will need a second reviewer, and the existing UGC self-review rules are unchanged.

### Revisions

Each claim has `moderation_status` (`pending`, `approved`, `rejected`, `hidden`) and `moderation_revision`. A material change increments the revision and returns the claim to pending, whatever path made it: the admin pages, the console or the importer. Material changes are:

- any claim column, including the Figure, target, predicate, dates, state, compensation, text, topic, practice context and role context
- adding, removing or editing an Attestation
- adding or removing a Practice on a practice relationship
- editing a Protocol's name, description or routine, which returns every claim that names it to pending

Several changes in one database transaction count as one revision. Creating a claim and its evidence in one import stays at revision 1. When a decided claim returns to pending, a `submitted` decision records what changed. A pending claim stays pending without a new decision.

### Decisions

`FigureClaims::Review` records one `ModerationDecision` per action, with the full `review_snapshot`:

| Action | From | To | Reason |
| --- | --- | --- | --- |
| publish | pending | approved | Optional; defaults to "Trusted admin publication". |
| reject | pending | rejected | Required. |
| withdraw | approved | hidden | Required. |
| reopen | rejected or hidden | pending | Optional. |

The snapshot holds the claim, the Figure, its targets (including the Protocol's method and the full Practice set) and every Attestation. Each review submits the revision, status and snapshot digest the admin previewed. The service locks the claim and refuses the action if any of them changed, so a stale preview can't publish newer content and a repeated submission can't record a second decision.

Publication also requires `publication_problems` to be empty: the claim must be valid, have at least one Attestation, and every Attestation must be complete. A practice relationship must name a Protocol or a Practice. Removing the last Attestation unpublishes a claim, and it can't be republished until new evidence is added and reviewed.

### Admin pages

**Admin → Figure claims** (`/admin/claims`) has:

- **List:** claims filtered by status and kind.
- **Editor:** one per kind. It resolves Figures by entity code and saves a practice relationship's Practice set together with the claim. A stale form is refused.
- **Evidence:** forms that record the Ace who entered each Attestation separately from its author.
- **Claim page:** a source preview, the publication problems, the review actions and the decision history.

**Businesses, practices, protocols & topics** (`/admin/claim-identities`) creates those records, building a code from the name when none is given. There is no edit: give a materially different method its own Protocol so approved claims keep the meaning they were reviewed with.

## Public pages

Every public page reads `published` claims and their Attestations only, including for admins. Pending, rejected and withdrawn claims never appear in cards, counts or lists. A claim that changes after publication disappears until it is published again.

**Figure pages** have three sections, in this order after appointments: **Businesses**, **Practices**, and **Values and wisdom**. Entries sort by start date (statement date for statements), most recent first, with unknown dates last and the entity code as a tie-breaker. An empty section says no sourced material has been recorded yet. A note separates sourced connections from fan ratings and posts and says they don't imply beliefs, medical effects or a team's position.

Each card shows:

| Card | Shows |
| --- | --- |
| Business | The predicate (Founded, Owns, Invests in, Endorses, Promotes, Sponsored by), the period, compensation for endorsements, promotions and sponsorships (Paid (documented), Unpaid (documented) or Compensation unknown), the investment vehicle and context. |
| Practice | The predicate, the Protocol (or General practice), every Practice this association names with the Figure's own explanation, and the period. A protocol-only claim says no practice interpretation was recorded. |
| Statement | The attribution kind and Topic, the text (direct quotes in quotation marks), who said it, the statement date, the role at the time, and the linked practice association when that is published. |

Periods never treat a missing end date as current:

| State | Label |
| --- | --- |
| `reported_current` | Reported current as of the as-of date, since the start date if known. |
| `historical` | The known period. |
| `planned` | Planned, from the start date if known. |
| `unknown` | Current status unknown, with any known dates. |

A founding shows only its date.

Each card's **sources** expand to its Attestations:

- the form, the original author (a Figure link or the credited name, otherwise "Author unknown"), the source title and publisher, and the publication date or "Publication date unknown"
- the text or excerpt, the segment or location, and the context
- links that open the source in a new tab; images with a media URL display with the excerpt as alt text and caption

The Ace who entered an Attestation is never shown publicly.

**Player pages** link to the Figure page as "Career, connections and values" and show published counts that link to each section.

**Reverse pages** list each person once, alphabetically by name then code, 20 per page, with all of their matching published claims:

| Page | Lists |
| --- | --- |
| `/businesses` | Businesses with published ties, with distinct-person counts and a predicate filter. |
| `/businesses/:id` | People and their ties, filtered by predicate and period. |
| `/practices` | Practices with person counts. Its filter form combines Practices, Protocol, connection and period; an association naming several selected Practices appears once. |
| `/practices/:id` | Associations naming that Practice, with their Protocols, filtered by connection and period. |
| `/protocols`, `/protocols/:id` | The method and each person's own association, with the Practices that person connects to it. |
| `/topics`, `/topics/:id` | Attributed statements, grouped by person. |

Organization pages don't list business ties. An empty filter says that nothing matches.

## Seeds

The `micharisma-seeds/v1` importer accepts `Business`, `FigureBusinessRelationship`, `Practice`, `Protocol`, `FigurePracticeRelationship`, `PracticeConnection`, `Topic`, `AttributedStatement` and `Attestation`. References use the association names: `figure`, `business`, `protocol`, `figure_practice_relationship`, `practice`, `topic`, `staff_tenure`, `observer`, `claim` and `author`. A `PracticeConnection` also matches an existing row by its relationship and Practice, so a replay with a new code can't duplicate a membership. Replays of unchanged records do nothing and keep review decisions. Changed values, including changed evidence, are reported as conflicts and never overwrite stored values. A new Attestation or Practice for an existing claim returns it to pending. Seeds can't set `moderation_status` or `moderation_revision`. All of these are core records in `UgcResetService`.

Only real, reviewed public evidence belongs in the catalog. Never fabricate claims about real people. Specs use fictional Figures.
