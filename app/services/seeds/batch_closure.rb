require Rails.root.join("lib/micharisma_seeders/lib/micharisma_seeders").to_s

module Seeds
  # Seed batches with everything they depend on. Identities live once each in
  # yaml/catalog/ and batches hold observations (see the data repository's
  # CONTRIBUTING.md, "Library layout"), so importing some batches on their own
  # needs the catalog records they reference, transitively, plus the catalog
  # records their generators write (listed in sources/<batch>/catalog_codes*.json;
  # an activation finds its Campaign through scope, not a code reference).
  class BatchClosure
    ROOT = Rails.root.join("db/seeds/athlete_ace_data")
    # Record types that live in the catalog (scripts/lib/seed_catalog.rb in the data repository).
    IDENTITY_TYPES = %w[Year Country State City Stadium Federation Sport Position Figure League Conference Division
      Team Organization Season Campaign Player].freeze

    def initialize(root: ROOT)
      @root = Pathname.new(root)
      registry = MICharismaSeeders::SequenceRegistry.read(@root.join("yaml/entity_sequences.yaml"))
      @rows = MICharismaSeeders::Reader.new(registry: registry)
        .read_many(Dir.glob(@root.join("yaml/**/*.{yml,yaml,json}")).reject { |path| path.end_with?("entity_sequences.yaml") })
      @index = Hash.new { |hash, key| hash[key] = [] }
      @rows.each { |row| ([ row.code ] + row.aliases).each { |code| @index[code] << row } }
      # Records can name a season only by league and year, and a campaign only
      # by team and season (an activation's scope), so index both by context.
      @seasons = @rows.select { |row| row.type == "Season" }.group_by { |row| context(row).values_at("league", "year") }
      @campaigns = @rows.select { |row| row.type == "Campaign" }.group_by { |row| [ context(row)["team"], season_code(row) ] }
    end

    # Reader rows for the batches (directories or files relative to yaml/),
    # the catalog codes their generators write, and every record they reference.
    def rows(*batches)
      pending = batches.flat_map do |batch|
        prefix = "/yaml/#{batch}"
        @rows.select { |row| (file = row.location.split(":").first).include?("#{prefix}/") || file.end_with?(prefix) } +
          Dir.glob(@root.join("sources/#{batch.delete_suffix(File.extname(batch))}/catalog_codes*.json")).sort
            .flat_map { |path| JSON.parse(File.read(path)).fetch("codes").flat_map { |code| @index.fetch(code) } }
      end
      selected = {}
      until pending.empty?
        row = pending.shift
        next if selected.key?(row.location)

        selected[row.location] = row
        (row.references.values + row.scope.values).each do |reference|
          pending.concat(@index.fetch(reference.is_a?(Hash) ? reference.fetch("code") : reference, []))
        end
        league, year = context(row).values_at("league", "year")
        pending.concat(@seasons.fetch([ league, year ], [])) if league && year && row.type != "Season"
        team = context(row)["team"]
        pending.concat(@campaigns.fetch([ team, season_code(row) ], [])) if team && row.type != "Campaign"
      end
      selected.values
    end

    # The rows as one importable manifest, written to path.
    def self.write(rows, path)
      records = rows.map do |row|
        { type: row.type, code: row.code, aliases: row.aliases, attributes: row.attributes,
          references: row.references, scope: row.scope, source: row.source }.compact
      end
      File.write(path, JSON.generate(format: "micharisma-seeds/v1", namespace: "MIC", catalog: "ALA", records: records))
      path
    end

    def context(row)
      row.scope.merge(row.references).transform_values { |value| value.is_a?(Hash) ? value.fetch("code") : value }
    end

    def season_code(row)
      context(row)["season"] || @seasons.fetch(context(row).values_at("league", "year"), []).first&.code
    end

    # One manifest per original file, in the original path order, so replay
    # order tests keep their meaning. Returns the paths written.
    def self.write_files(rows, directory)
      rows.group_by { |row| row.location.split(":").first.split("/yaml/").last }.sort.each_with_index.map do |(file, group), index|
        write(group, File.join(directory, format("%04d-%s.json", index, file.tr("/", "_"))))
      end
    end
  end
end
