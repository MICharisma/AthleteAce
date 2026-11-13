# League memberships

`Team.league` identifies a team's current league. `Membership` records that team's league affiliation, dates, and optional grouping.

| Structure | Membership relationships |
| --- | --- |
| League without groups | `team`, `league` |
| League with conferences | `team`, `league`, `conference` |
| League with divisions | `team`, `league`, `division` |
| League with conferences and divisions | `team`, `league`, `conference`, `division` |

Every division belongs to a league. Its conference is optional. A conference always belongs to a league.

When a membership supplies a division, validation fills missing conference and league links from that division. A conference supplies a missing league. Otherwise, the team's current league supplies the missing league. Existing callers that supply only `team` and `division` continue to work.

Supplied relationships must agree. A division and conference must belong to the membership's league. If a membership supplies a division, its conference must match that division's conference. A division without a conference cannot be placed in a conference through membership.

## Current and historical affiliations

An active membership must use the team's current league. `Team.conference` and `Team.division` use its active membership. Conference and division team lists show distinct teams with active memberships. Their `memberships` associations retain inactive history.

The existing `active` flag selects current memberships. Dates record history and do not change that flag automatically. The current-team interface expects one active membership per team. It does not expose concurrent primary conferences.

A historical membership can refer to an earlier league. When a team moves leagues, deactivate its old membership before changing `Team.league` and creating the new membership. Existing campaigns retain their recorded season, conference, and division. A campaign can have a conference without a division, or a division without a conference.

Teams remain visible in their current league even without a membership record. An additional title does not require another primary league membership. Competitions and title awards represent those championships separately.

## Seed records

The YAML importer accepts `league`, `conference`, and `division` references on memberships. The same names can come from inherited scope. A division accepts `league` and optional `conference` references. The model inference rules also apply to imports.

For example, a league-only membership can use an existing team's entity code:

```yaml
format: micharisma-seeds/v1
namespace: MIC
catalog: ALA
records:
  - type: Membership
    code: SOC-EPL-FUL-MEMBERSHIP
    references:
      team: SOC-EPL-TEAM-FUL
```

The importer preserves coded records on replay. Adoption of an uncoded membership matches the team, league, optional conference, optional division, and start date. Separate dated returns to the same group remain separate records.

Legacy JSON membership files can omit `conference_name` and `division_name`. They resolve teams within the named league. Their division lookup uses the supplied conference, or divisions directly under the league when no conference is supplied.

## Migration

Migration `20261113010000` adds league links to divisions and memberships and conference links to memberships. It fills those links from the existing hierarchy and preserves record IDs, entity codes, dates, and active flags. Division conference links and membership division links become optional.

Rollback refuses to restore the old required hierarchy while conference-free divisions or memberships without divisions exist. It does not delete those records.
