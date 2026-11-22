# Team palettes

`rails db:seed` runs `seeds:import`, then enriches existing coded teams with the primary and secondary colors recorded in `athlete_ace_data/sports`. This pass reads the NBA, NFL, and NHL team JSON catalogs and the Premier League palette file (`soccer/united_kingdom/Premier_League/team_palettes.json`). It does not create teams or match them by name or abbreviation alone; it resolves their league-qualified entity codes through the seed adapter. Retired catalog entries without a matching team are skipped.

Palette metadata follows the recorded JSON values on replay. Other team attributes retain the YAML importer's preservation policy. A custom `SEED_LIBRARY_ROOT` uses its own sibling `sports` directory, if present.

Teams save `text_color` as white or near-black, choosing whichever gives greater contrast against the primary color in linear sRGB. Changing the primary color recalculates the stored text color. Views use the saved value; incomplete or malformed palettes render the neutral fallback. Saved rounds snapshot all three colors so later team edits do not change an existing question.

Team colors appear on identity blocks and portraits. Answer buttons and correctness states retain the shared interface palette. Secondary colors appear as portrait bands and badge corners, with a theme-aware border on colored blocks.

The current catalog supplies palettes for all NBA, NFL, and NHL teams and for 22 of the 23 Premier League clubs. The Premier League and Utah colors are read from the league's official crest and logo SVGs; choosing which crest colors become primary and secondary is editorial. Sources and checksums are in `athlete_ace_data/sources/team_palettes_2026/`. Coventry City keeps a neutral block because its crest colors are embedded raster images. [Jersey-number history](jersey-numbers.md) supplies numbered portraits when the applicable number is known.
