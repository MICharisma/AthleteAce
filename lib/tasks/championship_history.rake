namespace :seeds do
  desc "Import championship history and fill missing annual campaign classifications"
  task championship_history: :environment do
    root = Rails.root.join("db/seeds/athlete_ace_data/yaml/championship_history")
    paths = %w[anchors.yml campaigns.yml championships.yml].map { |name| root.join(name).to_s }
    importer = Seeds::LibraryImporter.new
    validation = importer.validate(paths)
    report = nil
    ApplicationRecord.transaction do
      anchors = importer.call([ paths.first ])
      alignments = Seeds::CampaignAlignmentImporter.new(source: paths[1]).call
      raise Seeds::LibraryImporter::Error, "Recorded campaign alignments differ: #{alignments[:conflicts].to_json}" if alignments[:conflicts].any?

      history = importer.call(paths.drop(1))
      conflicts = anchors[:conflicts] + history[:conflicts]
      raise Seeds::LibraryImporter::Error, "Championship history conflicts: #{conflicts.to_json}" if conflicts.any?

      report = validation.merge(created: anchors[:created].size + history[:created].size,
        alignments_filled: alignments[:updated].size, conflicts: conflicts.size)
    end
    puts report.to_json
  end
end
