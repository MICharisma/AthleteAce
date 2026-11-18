require "rails_helper"
require "tempfile"

RSpec.describe Seeds::PrimaryMediaImporter do
  it "fills missing defaults, replays unchanged, and preserves an existing selection" do
    team = create :team, entity_code: "BKT-NBA-TEAM-HARBOR"
    first = Logo.create! owner: team, name: "Harbor mark", entity_code: "HARBOR-LOGO"
    alternate = Logo.create! owner: team, name: "Harbor alternate", entity_code: "HARBOR-ALTERNATE"
    Tempfile.create ["primary-media", ".json"] do |source|
      source.write JSON.generate(selections: [{type: "Team", code: team.entity_code, asset: first.entity_code}])
      source.flush
      importer = described_class.new source: source.path
      expect(importer.call[:updated]).to eq [team.entity_code]
      expect(team.reload.primary_logo).to eq first
      expect(importer.call[:unchanged]).to eq [team.entity_code]
      team.update! primary_logo: alternate
      expect(importer.call[:conflicts]).to eq [{code: team.entity_code, existing: alternate.entity_code, incoming: first.entity_code}]
      expect(team.reload.primary_logo).to eq alternate
    end
  end
end
