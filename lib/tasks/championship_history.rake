require "tmpdir"

namespace :seeds do
  desc "Import championship history and fill missing annual campaign classifications"
  task championship_history: :environment do
    # The batch's observations plus its catalog identities (its anchors and
    # annual campaigns, and everything they reference).
    rows = Seeds::BatchClosure.new.rows("championship_history")
    campaigns = rows.select { |row| row.type == "Campaign" }
    observations = rows.reject { |row| row.type == "Campaign" || Seeds::BatchClosure::IDENTITY_TYPES.include?(row.type) }
    anchors = rows - campaigns - observations
    importer = Seeds::LibraryImporter.new
    report = nil
    Dir.mktmpdir("championship-history") do |directory|
      anchors_path = Seeds::BatchClosure.write(anchors, File.join(directory, "anchors.json"))
      history_path = Seeds::BatchClosure.write(campaigns + observations, File.join(directory, "history.json"))
      validation = importer.validate([ anchors_path, history_path ])
      ApplicationRecord.transaction do
        anchor_report = importer.call([ anchors_path ])
        # Fill missing classifications first, so existing campaigns do not report them as conflicts.
        alignments = Seeds::CampaignAlignmentImporter.new(records: campaigns).call
        raise Seeds::LibraryImporter::Error, "Recorded campaign alignments differ: #{alignments[:conflicts].to_json}" if alignments[:conflicts].any?

        history = importer.call([ anchors_path, history_path ])
        conflicts = anchor_report[:conflicts] + history[:conflicts]
        raise Seeds::LibraryImporter::Error, "Championship history conflicts: #{conflicts.to_json}" if conflicts.any?

        report = validation.merge(created: anchor_report[:created].size + history[:created].size,
          alignments_filled: alignments[:updated].size, conflicts: conflicts.size)
      end
    end
    puts report.to_json
  end
end
