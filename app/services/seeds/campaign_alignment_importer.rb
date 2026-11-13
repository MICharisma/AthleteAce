module Seeds
  class CampaignAlignmentImporter
    def initialize(source:)
      @source = source
    end

    def call
      importer = LibraryImporter.new
      report = { updated: [], unchanged: [], conflicts: [] }
      ApplicationRecord.transaction do
        importer.read([ @source ]).each do |record|
          next unless record.type == "Campaign"

          campaign = importer.resolve_code("Campaign", record.code)
          next unless campaign

          team = importer.resolve_code("Team", record.references.fetch("team"))
          season = importer.resolve_code("Season", record.references.fetch("season"))
          raise LibraryImporter::Error, "Campaign identity differs: #{record.code}" unless campaign.team == team && campaign.season == season

          desired = { division: required_record(importer, "Division", record.references.fetch("division")),
            conference: record.references["conference"] && required_record(importer, "Conference", record.references.fetch("conference")) }
          conflicts = desired.filter_map do |key, value|
            key if campaign.public_send(key) && campaign.public_send(key) != value
          end
          if conflicts.any?
            report[:conflicts] << { code: record.code, fields: conflicts }
            next
          end
          changes = desired.select { |key, value| campaign.public_send(key).nil? && value }
          if changes.empty?
            report[:unchanged] << record.code
          else
            campaign.update! changes
            report[:updated] << record.code
          end
        end
      end
      report
    end

    private

    def required_record(importer, type, code)
      importer.resolve_code(type, code) || raise(LibraryImporter::Error, "Missing #{type} #{code}")
    end
  end
end
