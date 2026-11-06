# Figures, coaches, staff, and broadcasters

`Figure` identifies someone across athletic profiles, coaching work, organizational staff roles, and broadcasting appointments. A Figure can exist without a Player or an Ace account. Admin People continues to manage Ace accounts.

## Identity and athletic profiles

Every Player belongs to one Figure through the required `players.figure_id` foreign key. A Figure can have several Players, including profiles for different sports. New Players create a Figure in the same transaction unless one is supplied.

Names live on Figure. Players delegate `name`, `short_name`, `sort_name`, `name_segments`, `alternate_names`, `first_name`, `last_name`, and `nicknames` to their Figure. Editing a Player's first name, last name, or nicknames updates that shared identity. Search matches the Figure's names without requiring accents. See [seed name attributes](yaml-seed-library.md#figures-and-names) for name-form rules.

Generated Figure codes use `FIGURE-` followed by the Player's entity code. Uncoded Players receive a UUID-based Figure code. A transfer or name change does not change that code. Names are display attributes, never merge keys.

Deleting a Player leaves its Figure and appointments intact. Recreating a coded Player reattaches its Figure through the generated code or an `EntityCode` alias. A supplied first name, last name, or nickname on the replacement updates the reclaimed Figure. Rebuilding an uncoded profile cannot recover its previous identity automatically.

Figure deletion is restricted while Players or appointments refer to it. The Figure's Rizz sync record is deleted with the Figure.

The rename migration changes `people` to `figures` and renames the identity foreign keys in `players`, `staff_tenures`, and `rizz_syncs`. Existing database contents are disposable before launch. The migration does not convert stored polymorphic types or old provisional codes. Recreate the database before importing the updated catalog.

## Appointments

`StaffTenure` records a Figure, an Organization, an optional Team, a role, a title, dates, an entity code, source metadata, and optional details. Its role is `coach`, `staff`, or `broadcaster`. The title preserves a specific job, such as Assistant coach, Performance director, or Color commentator.

The Organization is the employer or appointing organization. The Team is the appointment's explicit sporting context. A broadcaster can work for a media organization and cover a team without that media organization owning the team. A tenure without a Team is labeled Organization-wide and appears only on the organization and Figure pages.

Concurrent roles, same-day transitions, and return tenures are allowed. Each appointment has its own entity code. Different source records about the same appointment must reuse that code or declare aliases. A different code does not automatically merge appointments by name or dates.

`start_date` and `end_date` store text at the source's precision:

| Value | Meaning |
| --- | --- |
| `2025` | Only the year is known. |
| `2025-07` | The year and month are known. |
| `2025-07-07` | The calendar day is known. |
| null | The date is unknown. |

Validation rejects invalid dates and a start range entirely after the end range. An exact end day is inclusive. Partially known ranges may overlap. A missing end date means Unknown end. Only an affirmative `ongoing: true` displays Present, and an ongoing appointment cannot have an end date. The app does not infer current membership or a season from incomplete dates.

Appointments sort by start-date text descending, with undated rows last and IDs as a stable secondary key. Public lists include historical appointments. Figure, Organization, and Team deletion is restricted while appointments refer to them.

## Browsing

Organization pages list coaches, staff, and broadcasters. Team pages have a **Coaches, staff & broadcasters** tab that shows appointments with an explicit reference to that Team. Each row links its Figure, organization, optional team, and available source URL. Figure pages link their athletic profiles and list their appointments. Athletic profiles link back to career history.

These are public catalog views. There are no new public write endpoints or changes to account permissions. Staff records enter through the seed importer or existing trusted Rails maintenance access. A source records where an appointment claim came from, rather than proving employment, ownership, or consent.

## Seeds and rebuilds

The `micharisma-seeds/v1` importer accepts `Figure` and `StaffTenure`. Players reference a Figure through `references.figure` or inherited `scope.figure`. StaffTenure can reference a Figure, organization, and team through references or inherited scope. A staff appointment requires nonempty source metadata.

A Figure definition can register aliases for an existing Figure code. Replays preserve differing values and report conflicts. The importer rejects `Person` records and reverse `Figure.references.player` links.

Figures and appointments are core catalog records in `UgcResetService`. A full catalog reset deletes them with the other core records. Portable Figure and StaffTenure definitions recreate sourced staff history after a reset. UUID identities for uncoded Players remain local identities.

The catalog files and published seed schemas still use the old Person contract during the app rename phase. Full catalog imports and catalog coverage checks require the subsequent seed update. Small Figure fixtures and factories exercise the app independently of that catalog.

## Rizz sync

`bin/rails rizz:sync_figures` sends Figures with athletic profiles to Rizz. It requires the optional `rizz-client` gem, `RIZZ_ENDPOINT`, and `RIZZ_API_TOKEN`. The local `RizzFigureSync` adapter retains the external SDK's `PersonRecord` and `import_athleteace_person` interfaces until Rizz is updated.

An accepted `MIC-RZZ-` code becomes the Figure's canonical `entity_code`. Earlier codes remain aliases. `RizzSync.figure` records the snapshot revision, remote entity, and sync state. Unchanged synced snapshots are skipped. Review responses wait for a later sync, and duplicate local holders require a local merge.
