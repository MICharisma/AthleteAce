# Working on AthleteAce

This file provides guidance to coding agents working in this repository. `CLAUDE.md` imports it.

## Development Commands

### Ruby through mise
This app loads Ruby 4.0.7 through mise, pinned in `mise.toml`. A `ruby` already on `PATH` is usually a different version, so check mise before reporting that Ruby is missing.

- `mise install` installs the pinned Ruby if it isn't there yet.
- Prefix Ruby commands with `mise exec --`: `mise exec -- ruby -S bundle install`, `mise exec -- ruby bin/rails db:migrate`, `mise exec -- ruby -S bundle exec rspec`.
- Or activate mise once per shell with `eval "$(mise activate bash)"` (or `zsh`) and run the commands bare.

### Database Operations
- `rails db:seed` - Import the scoped YAML/JSON library under `db/seeds/athlete_ace_data/yaml/`
- `rails db:reset` - Drop, create, migrate, and seed database
- `rails db:migrate` - Run pending migrations

### Testing
Read `docs/testing.md` before writing or changing a spec. It covers which layer to test in, the bug-fix recipe, and the interaction specs that replace browser tests.

- `npm install` - Install jsdom and esbuild for interaction specs (once per checkout)
- `bundle exec rspec` - Run the default suite, in random order
- `bundle exec rspec spec/models/player_spec.rb` - Run specific test file
- `bundle exec rspec --only-failures` or `--next-failure` - Rerun what failed last time
- `bundle exec rspec --tag seed_library` - Run the examples that import the real seed library (several minutes). The default suite leaves them out; run them when the seed data or the importer changes
- `COVERAGE=1 bundle exec rspec` - Write a SimpleCov report to `coverage/`

### Code Quality
These commands are optional manual tools. Automated CI is deferred until launch preparation; see `README.md`.

- `bundle exec rubocop` - Run Ruby style linter
- `bundle exec brakeman` - Run security analysis

### Development Server
- `bin/dev` - Start development server with Procfile.dev (Rails + Tailwind CSS)
- `rails server` - Start Rails server only
- Puma-dev server running at http://athleteace.test (primary development server)
- Can start another server with `binding.break` for debugging purposes

## Architecture Overview

### Core Domain Models
AthleteAce is a sports data application with hierarchical relationships:
- **Sports** → **Leagues** → **Conferences** → **Divisions** → **Teams** → **Players**
- **Countries** → **States** → **Cities** → **Stadiums**
- **Memberships** track team participation in divisions over time
- **Ratings** system with configurable **Spectrums** for player evaluation
- **Quests/Achievements** gamification system

### Filterable System
The application's core feature is a sophisticated filtering system that allows navigation through related resources:

- **Filterable Concern** (`app/controllers/concerns/filterable.rb`): `apply_filter` scopes a collection through the filtering record's association (e.g. `@team.players`)
- **FilterLoader** (`app/controllers/concerns/filter_loader.rb`): Loads current filters and builds breadcrumbs for filtered show pages
- **FilterableAssociations** (`config/initializers/filterable_associations.rb`): Centralized configuration defining which models can filter others; each listed model must define an association named for the resource
- **Modular Routes** (`config/routes/filterable.rb`): DSL for generating filtered index/show routes
- **View Helpers**: `association_links` (TeamsHelper) and `filtered_show_header` (FilteredShowHelper)

Key filterable URLs: `/teams/123/players`, `/teams/123/players/456` (one level of nesting). See `docs/filterable.md`.

### Data Seeding Architecture
- **Maintained library**: YAML and JSON manifests use the `micharisma-seeds/v1` envelope under `db/seeds/athlete_ace_data/yaml/`.
- **Stable identity**: Scoped semantic codes and aliases resolve records through `Seeds::LibraryImporter`; file names do not define identity.
- **Replay**: Missing records are created, existing values are preserved, and differences are reported. Team palette enrichment separately refreshes recorded colors.
- **Entry point**: `db/seeds.rb` invokes `seeds:import`. The old JSON orchestration remains in `db/seeds_legacy.rb` for explicit legacy use.
- **Reference**: See `docs/yaml-seed-library.md` for input contracts, migration requirements, and coverage.
- **Curation skills**: `db/seeds/athlete_ace_data/skills/` (symlinked into `.claude/skills/`) guide gathering web data and curating it into seeds; start with `seed-curation`.

### UGC Preservation System
- **Backup Location**: `db/seeds/athlete_ace_ugc/backups/` (Git submodule for version control)
- **Identifier-Based Remapping**: Preserves user data during core model reseeding
- **Commands**: `rails ugc:backup`, `rails ugc:restore[timestamp]`, `rails "ugc:full_reseed[float|clear]"`
- **Reset modes**: `float` (default) keeps ratings, achievements, and game attempts, which attach to whichever new records reuse their ids (useful as sample content); `clear` deletes them with the core data so `ugc:restore` recreates them against the right records, and requires a backup newer than the latest change to them
- Plain `rails db:seed` keeps ids and UGC intact, preserves catalog values, reports conflicts, and separately refreshes team palettes; the reset is only for clearing out records that seeding can't remove
- **Documentation**: See `docs/ugc_preservation_system.md` for complete implementation details

### Authentication & Games
- **Devise** for user authentication (`Ace` model)
- **Strength Training**: Various game modes for learning athlete names
- **Division Guessing**: Interactive games with attempt tracking via `GameAttempt` model

## Code Conventions

### Ruby Style
- Omit parentheses in method calls and argument lists wherever the syntax is clear
- Chain a few methods to map a collection into a result instead of storing intermediate values
- Use lookup-table-style methods rather than if/else when a configuration depends on the model or record being displayed
- Describe arguments in comments only when the method and variable names leave their role unclear
- Extra blank lines are not needed except in methods over 10 lines long

### Templates and Helpers
- Use Rails tag builders instead of raw HTML in ERB templates
- Turn reusable blocks into helper methods, parametrized so they can serve multiple domain models
- Compose markup by concatenating tag builders with `+`, so the code mirrors the resulting HTML; every method on either side of a `+` needs parentheses
- If a tag's content is one method call, pass it as the second argument rather than using a block
- Three template types: admin scaffolds, user scaffolds, custom interfaces
- Interface phrases belong in a YAML locale file so the interface can be translated
- Shared helpers can name a group of domain models (Country, State, and City are all locations); pause and ask before establishing a new term

### CSS/Styling
- **Tailwind CSS**, with semantic class names in markup
- Apply utilities with `@apply` in stylesheets, not in templates or helpers; existing utility classes in markup are the old approach, not a pattern to extend
- Define a style at the highest level it applies to, and nest rules under a contextual parent class
- Declare colors with CSS variables
- Utilities under one `@apply` can be grouped across lines by purpose; a brief comment may explain a less common one

### Helper Method Parameters
Choose appropriate parameter passing:
- `@variables` for controller instance variables
- Method parameters for explicit values
- Hash elements for optional configurations

### DOM IDs
Use descriptive suffixes: `dom_id(team, :quiz_link_for)` rather than `dom_id(team, :quiz_link)`

## Technology Stack
- **Rails 8.1.4** with Ruby 4.0.7 (pinned in `.ruby-version` and `mise.toml`; keep them in sync)
- **PostgreSQL** database with separate schemas for cable/cache/queue
- **Tailwind CSS 4.3** for styling
- **Turbo/Stimulus** for JavaScript interactions
- **RSpec** for testing with FactoryBot, rails-jsdom (interaction specs), insta (interface snapshots), Capybara with Selenium (layout only), Shoulda Matchers
- **Pagy 43** for pagination (`Pagy::Method`, `@pagy.series_nav`, defaults in `Pagy::OPTIONS`)
- **Ransack** for search functionality
- **Devise** for authentication

## Development Guidance
- Let's not add handling for various input types (hash, array, string) until we need it.

## Seed data curation

Before gathering sports data from the web or editing seed manifests, read the curation skills in `db/seeds/athlete_ace_data/skills/`, starting with `seed-curation/SKILL.md`. They cover source selection and evidence, provider endpoints, entity identity, manifest rules, geography, historical claims, and team visuals. Claude Code loads them automatically through the `.claude/skills/` symlinks.
