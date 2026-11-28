# NCAA, High School, and Multi-Team Organization Findings

Recorded 2026-11-27 alongside the initial team league/sport display helpers in AthleteAce.

## Posting status

Posted to the AthleteAce (`AA`) Linear team.

- [AA-276](https://linear.app/athleteace/issue/AA-276/multi-team-organization-support-for-colleges-high-schools-and-multi) Multi-team Organization support for colleges, high schools, and multi-sport/youth clubs
- [AA-277](https://linear.app/athleteace/issue/AA-277/refine-game-modes-for-college-high-school-and-youthmulti-team) Refine game modes for college, high school, and youth/multi-team organizations
- [AA-278](https://linear.app/athleteace/issue/AA-278/ncaa-federation-and-seed-pipeline-readiness) NCAA Federation & seed pipeline readiness

The existing schema can probably support colleges. Revisit the model once the work is further along.

## Implemented baseline (ready now)

- **League & team context API:** `League#short_name`, `League#context_label`, `Team.normalized_name`, `Team.ambiguous_names`, `Team#league_sport_label`, `Team#name_with_context`, `Team#name_ambiguous?`, and `Team#disambiguated_name`.
- **View helpers (`TeamsHelper`):** `team_context_label`, `team_name_ambiguous?`, `team_display_name` (`:auto` / `:always` / `:never`), and `team_name_with_context`.
- **Wired surfaces:** `OrganizationsController` index (8-team pill cap + `+N more` overflow + short context) and show (sorted by sport/league with full league/sport labels), `ShellSearch` team subtitles, `GameRoundSetup` team picker (`league_id` blank disambiguation), `player_team_match` & `multiple_choice` colliding answer choices, `on_the_team` colliding focus-team prompt, and `flash_cards` colliding team phrase.

---

## Ready-to-post Linear issues (`AA`)

### 1. Multi-team `Organization` support for colleges, high schools, and multi-sport/youth clubs

**Why**
Currently 0 `Organization` records in development hold more than one `Team`, and the 16 seeded Ivy League teams have `current_organization = nil`. Once colleges (20–40 varsity programs), high schools, European polysportive clubs (e.g., FC Barcelona), or youth/academy pyramids are linked under one `Organization`, users will expect to browse and study an entire organization cleanly.

**Scope**
- Seed `Organization` and `OrganizationAffiliation` records for the 8 Ivy League schools (`db/seeds/athlete_ace_data/sources/ncaa_ivy_2026/`) as the first live multi-team organizations in dev.
- Include `HasLogos` on `Organization` (`app/models/organization.rb`) so multi-team schools/clubs carry first-class logos alongside `Team`, `League`, `Conference`, and `Division`.
- Decide whether `Organization` becomes a first-class play, filter, and curation scope:
  - Add `:organization_id` to `GameRoundSetup` (`app/models/game_round_setup.rb`)
  - Add `"Organization"` to `Achievement::TARGET_TYPES` and `PRACTICE_SCOPES` (`app/models/achievement.rb`)
  - Add `:organization` to `FilterLoader#sort_filters_by_hierarchy` (`app/controllers/concerns/filter_loader.rb`)
- Add sport/league grouping or filtering on `OrganizationsController#show` (`app/views/organizations/show.html.erb`) for departments with 20–40 current teams.
- Consider exposing `Organizations` in non-admin `ShellSearch` (`app/queries/shell_search.rb`, currently `admin` side only).

---

### 2. Refine game modes for college, high school, and youth/multi-team organizations

**Why**
US pro leagues mostly have unique `Team#name` values and clean 1-sport `Organization` mappings. Colleges, high schools, national federations, polysportive clubs, and youth academies reuse the same mascot/club name across sports, genders, and age groups.

**Scope**
- **Gate pro-centric guessing games by unambiguity (`TeamFactRound`):**
  - `guess_the_league`: eligible only when a team's normalized `Team#name` maps to a single `League` (skips *Yale Bulldogs* across Men's/Women's Basketball and *Arsenal* across EPL/WSL/U15).
  - `guess_the_sport`: eligible only when all teams sharing that normalized `Team#name` (or `current_organization`) play a single `Sport` (allows single-sport club pyramids like *Arsenal*, skips multi-sport schools like *Yale* or *FC Barcelona*).
  - Add an optional league-level disambiguation/program-sharing flag (e.g., for college, high school, national-team, and youth leagues) so partially seeded catalogs don't ask misleading league/sport questions before sibling sports are imported.
- **Extend `guess_the_division` (`DivisionGameSetupService` / `GameRoundSetup`):**
  - Support conference-level guessing (or conference fallback) for leagues with conferences and zero divisions (e.g., NCAA D1 Men's & Women's Basketball).
  - Include league/sport context in the prompt so split-conference schools (e.g., Notre Dame across ACC, Big Ten Hockey, FBS Independent) remain unambiguous.
- **Keep `PlayerFactRound` (`multiple_choice` / `image_recognition`) clean:**
  - Verify distractors and scope behavior when practicing across multi-gender or multi-sport pools so colliding team choices always render league/sport labels and sensible same-pool distractors.
- **Lift round setup scale limits (`GameRoundSetup`):**
  - Revisit the 30-team cap on `selected_team_ids` (Stanford/Harvard/Ohio State field 35–42 varsity teams) and `limit(100)` on `selectable_teams` (full NCAA D1 basketball exceeds 700 teams).
- **Youth academies & shared conference names:**
  - Document naming conventions for age-group squads (`U15`, `U18`, `U21`, `JV`, `Boys`/`Girls`) vs. `League` separation.
  - Disambiguate `Conference#display_name` (`app/models/conference.rb`) when identical conference names appear in multiple leagues (e.g., Men's vs. Women's `Ivy League (Ivy)`).

---

### 3. NCAA `Federation` & seed pipeline readiness

**Why**
`BKT-LEAGUE-NCAA_D1_MEN` and `BKT-LEAGUE-NCAA_D1_WOMEN` are currently seeded under `COUNTRY-US` jurisdiction, without school `Organization` records, venues, colors, or logos, and `Federation` (`app/models/federation.rb`) has no associations yet.

**Scope**
- Decide `FEDERATION-NCAA` (or conference/association federations) vs. `COUNTRY-US` on NCAA leagues and flesh out `Federation` associations/views (`app/models/federation.rb`, `app/views/federations/_federation.html.erb`) comparable to UEFA / FIA.
- Extend `db/seeds/athlete_ace_data/scripts/capture_ncaa_ivy_2026.rb` and `build_ncaa_ivy_2026.rb` (and downstream geography/media builders) to seed:
  - School `Organization` + `OrganizationAffiliation` bindings
  - Home venues/`Stadium` bindings
  - Team color palettes (`primary_color`, `secondary_color`) and logos before scaling NCAA imports beyond the Ivy League basketball pilot.
