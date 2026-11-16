# Add and ingest seed media

Canonical files live in the public [athlete_ace_media](https://github.com/MICharisma/athlete_ace_media) repository. It is independent of the application and seed-data repositories and is not a submodule. The data repository owns the Logo, Uniform, UniformPiece, and AssetRepresentation definitions, including original source provenance.

Logos use `references.owner` to name a Sport, League, Conference, Division, or Team. Each of those entities stores its optional `primary_logo_id`, validated against the logo's owner. Figure headshots are AssetRepresentations whose `references.subject` names the Figure; the Figure's optional `primary_portrait_id` selects its default. Separate representations retain the NBA and ESPN headshots without treating either as historical jersey evidence.

## Add a file

1. Save the original file in the media repository, for example `logos/BKT-NBA-TEAM-PHI/primary.svg`. Keep the source page URL, original image URL, and capture date. Distinct artwork gets a distinct Logo record; formats and views of the same artwork get separate AssetRepresentation records.
2. Commit and push the media file. Record the full 40-character commit SHA, the file's SHA-256, and its byte size.
3. Add an AssetRepresentation to the seed library with its owner reference, file metadata, and a pinned GitHub source. Retain the original provenance alongside the repository location:

   ```yaml
   source:
     url: https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams/18/roster?season=2027
     github:
       repository: MICharisma/athlete_ace_media
       commit: ff5efeced75e7b78d3b43738a5fe57aa053155a7
       path: pilot/knicks-primary.png
   ```

   This example points to the existing Knicks pilot file. Set the source URL and file location to match the asset being added. `canonical_path` remains a logical catalog path such as `media/pilot/knicks-primary.png`; it is not a runtime disk location. `source.github.path` is relative to the media repository root. Branch names, abbreviated commit SHAs, absolute paths, and traversal segments are rejected.
4. Validate and import the seed library from the application checkout:

   ```sh
   mise exec -- ruby -S bundle exec rails db:migrate
   mise exec -- ruby -S bundle exec rails seeds:validate db:seed
   mise exec -- ruby -S bundle exec rails seeds:assets:verify
   ```

   Validation must report positive file and record counts. An import error, nonzero exit, or failed size/checksum check means ingestion did not finish. Verification must report a positive number of stored files. Repeating the import must report unchanged files without creating more attachments or fetching those files from GitHub again.

## Storage and deployment

`db:seed` invokes `seeds:assets:import` after the catalog import. The task uses `https://raw.githubusercontent.com/<repository>/<commit>/<path>` with no credentials because the media repository is public. It fetches one file at a time, checks the expected byte size and SHA-256, then attaches it to the representation through Active Storage. Oversized responses are stopped, and HTTP errors or redirects are rejected. A failed download does not attach the response. Completed files remain available if a later file fails; rerun the task to resume.

The default Disk service writes under `storage/` in development and `/rails/storage` in the container. The deployed service must retain its persistent volume at `/rails/storage`. Media ingestion does not put files in the Docker image, and `.dockerignore` excludes the old local seed-media directory. `SKIP_SEEDS=1` continues to skip catalog and media ingestion at deployment.

Use `asset.file` with Rails' Active Storage URL helpers to serve an ingested file. Browser requests use the stored copy, not GitHub. Existing attachments are verified against the recorded size and SHA-256 on replay. Missing storage files or files that differ from their recorded size or checksum produce an error rather than silently accepting or replacing the file.

The catalog importer still preserves existing values and reports conflicts. When moving an existing catalog to a new media source, explicitly reconcile the representation's `source.github` metadata after checking the existing checksum. A seed conflict does not authorize overwriting catalog metadata. Do not purge a curated attachment merely to suppress a checksum mismatch.

After file ingestion, `Seeds::PrimaryMediaImporter` reads `sources/nba_media_2026/primary.json`. It fills missing logo and portrait defaults, reports unchanged selections, and preserves existing choices as conflicts instead of overwriting them. The generated selections are applied after the owners and files exist, avoiding circular seed dependencies.

Player pages show their selected Figure portrait and the selected logos in their breadcrumbs. Logo links reveal their text on hover or focus; devices without hover keep labels visible. Breadcrumbs without a sourced logo retain their icon and label. PNG renditions are preferred over SVG originals for inline logo display because Active Storage serves SVG files as downloads.

Related collections, including the teams on a league page, use each entity's selected stored logo and fall back to its legacy logo URL when no stored logo is selected. Explicit image attributes, such as player photo URLs, keep their existing behavior.

## NBA and LeBron media batch

The November 15, 2026 capture loads all 480 team-logo variants listed in the recorded NBA feed, one official NBA league mark, and LeBron's NBA and ESPN headshots. Two Knicks files reuse existing pilot representations. A PNG rendition of the league SVG is separately identified as rasterized source artwork. Together with the earlier pilot, application storage contains 506 canonical files. The capture establishes image availability on that date, not logo introduction dates or historical uniform accuracy.

`scripts/capture_nba_media.py` in the data repository takes `--as-of` and `--media-root`. It downloads source images into the independent media checkout, records checksums and content types, and lists unavailable sources without bypassing their access restrictions. After publishing those files, update `sources/nba_media_2026/media.json` to their full commit SHA. The offline `scripts/build_nba_media.rb` generator writes the media manifest and default selections; `--check` exits nonzero if generated output differs. The original league SVG and its separately pinned PNG rendition are recorded in `capture.json` and `renditions.json`.

## Regenerate the visual pilot

`sources/coverage_2026/media.json` in the data repository pins the pilot's media commit and records all 24 file hashes and sizes. The offline `scripts/build_visual_assets.rb` generator reads that capture to emit the representation metadata. It does not download files. Its `--check` option exits nonzero if generated output differs; it also rejects illustrative geometry that differs from the pinned file checksum.

The developer preview generated by `scripts/preview_visual_assets.rb` reads the pinned raw URLs directly. This preview is separate from application rendering, which serves ingested copies from Active Storage.
