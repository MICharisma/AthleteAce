require "rails_helper"
require "tmpdir"

RSpec.describe Seeds::SeasonDateImporter do
  def records(start_date:, end_date: nil)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "seasons.json")
      File.write(path, JSON.generate(format: "micharisma-seeds/v1", namespace: "MIC", catalog: "ALA", records: [
        { type: "Season", code: "BKT-NBA-SEASON_2003_2004", attributes: { label: "2003_2004", start_date: start_date, end_date: end_date }.compact }
      ]))
      [ path, Seeds::LibraryImporter.new.read([ path ]) ]
    end
  end

  let!(:season) { create :season, entity_code: "BKT-NBA-SEASON_2003_2004", label: "2003_2004" }

  it "fills dates an existing season lacks, then leaves them unchanged" do
    _, rows = records(start_date: "2003-10-28", end_date: "2004-04-14")
    expect(described_class.new(records: rows).call[:updated]).to eq([ season.entity_code ])
    expect(season.reload.attributes.slice("start_date", "end_date").values).to eq([ Date.new(2003, 10, 28), Date.new(2004, 4, 14) ])
    expect(described_class.new(records: rows).call[:unchanged]).to eq([ season.entity_code ])
  end

  it "reports a recorded date that differs and leaves the season unchanged" do
    season.update! start_date: "2003-10-27"
    _, rows = records(start_date: "2003-10-28", end_date: "2004-04-14")
    report = described_class.new(records: rows).call
    expect(report[:conflicts]).to eq([ { code: season.entity_code, fields: %w[start_date] } ])
    expect(season.reload.end_date).to be_nil
  end
end
