# Rating history

`ratings` supplies current opinions through its `active` scope. Replacing an
opinion still archives the prior row and creates the replacement under the
Ace's lock. An identical value and notes reuse the current row.

`rating_revisions` separately records successful rating creation, opinion edits,
archiving and removal in the same transaction. Each event snapshots the value,
notes, local target and Spectrum IDs, archive state and full dimension definition.
The definition retains the question, labels, scale version, bounds and precision
steps used at that time. Rejected writes and unchanged saves add no revisions.

An `archive` event refers to its source rating, not to a withdrawal of the newer
active opinion. A `remove` event records the source rating's final state,
including whether that row was archived. Revisions survive removal of the source
rating, target or Spectrum. Deleting the owning Ace deletes their personal history.

The new table begins recording when this migration is installed. It does not
reconstruct earlier changes; existing archived rows remain available as before.
The shared ratings package owns scale and gesture behavior. AthleteAce owns its
records, history and access rules. No history endpoint or transmission to Rizz
is added. Future permissioned transmission is tracked separately in
[MIC-70](https://linear.app/micrizz/issue/MIC-70/connect-app-owned-rating-history-to-rizz-preferences-after-sharing-is).
