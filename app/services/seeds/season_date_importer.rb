module Seeds
  # Fills missing regular-season dates on existing seasons from Season seed
  # records (Reader rows) and reports recorded dates that differ. The library
  # import preserves existing values, so it would only report a date that a
  # season gained after it was first imported.
  class SeasonDateImporter
    FIELDS = %w[start_date end_date].freeze

    def initialize(records:)
      @records = records
    end

    def call
      importer = LibraryImporter.new
      report = { updated: [], unchanged: [], conflicts: [] }
      ApplicationRecord.transaction do
        @records.each do |record|
          next unless record.type == "Season"

          incoming = record.attributes.slice(*FIELDS).transform_values { Date.iso8601(it.to_s) }
          next if incoming.empty?

          season = importer.resolve_code("Season", record.code)
          next unless season

          conflicts = incoming.filter_map { |key, value| key if season.public_send(key) && season.public_send(key) != value }
          if conflicts.any?
            report[:conflicts] << { code: record.code, fields: conflicts }
            next
          end
          changes = incoming.select { |key, _| season.public_send(key).nil? }
          if changes.empty?
            report[:unchanged] << record.code
          else
            season.update! changes
            report[:updated] << record.code
          end
        end
      end
      report
    end
  end
end
