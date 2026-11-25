# Rating history

`Rating` identifies the evaluated entity through `rated`, a polymorphic association
backed by `rated_type` and `rated_id`. `ratings` supplies current opinions through its `active` scope. Replacing an
opinion still archives the prior row and creates the replacement under the
Ace's lock. An identical value and notes reuse the current row.

`rating_revisions` separately records successful rating creation, opinion edits,
archiving and removal in the same transaction. Each event snapshots the value,
notes, local rated-entity and Spectrum IDs, archive state and full dimension definition.
The definition retains the question, labels, scale version, bounds and precision
steps used at that time. Rejected writes and unchanged saves add no revisions.

An `archive` event refers to its source rating, not to a withdrawal of the newer
active opinion. A `remove` event records the source rating's final state,
including whether that row was archived. Revisions survive removal of the source
rating, target or Spectrum. Deleting the owning Ace deletes their personal history.

`CallRatingEntitiesRated` renames the reference columns on current ratings and
revisions while preserving their data. `RatingService.replace` now takes `rated:`.
The UGC backup format retains its existing `target_*` keys, and restore maps those
keys to the `rated` association so existing backups remain readable.

The history table records new events and does not reconstruct earlier changes.
The subsequent standard-scale migration starts ratings and their history afresh,
as described below.
The shared ratings package owns scale and gesture behavior. AthleteAce owns its
records, history and access rules. No history endpoint or transmission to Rizz
is added. Future permissioned transmission is tracked separately in
[MIC-70](https://linear.app/micrizz/issue/MIC-70/connect-app-owned-rating-history-to-rizz-preferences-after-sharing-is).

## Standard scale

Dimension version 2 uses the shared −100 to +500 scale, with neutral zero and
coarse/fine steps of 10/1. Missing remains different from an explicit zero.
High Affinity begins at 250 for My teams and preferred-team practice.

`AdoptStandardRatingScale` removes existing ratings and rating revisions before
adding the database range constraint. This approved fresh start does not convert
old values and cannot be rolled back. Account, catalog and Spectrum records stay.
Run the app migrations before serving the new code. New revisions snapshot the
version 2 definition. Ascent's separate mountain voting range is unaffected.

## Rating dimensions and controls

Open Rating dimensions at the top right of the page to choose which sliders
appear on browse and detail pages. Turn on Multiple to show more than one
dimension. The selection follows you through the current browser session.

Start dragging from the slider handle and move down for finer adjustments.
On the keyboard, hold Shift while pressing an arrow key for single-point changes.
The diamond on the track marks the Aces average. The count includes active
ratings on that dimension.
