require "rails_helper"
require "tmpdir"
require Rails.root.join("db/seeds/athlete_ace_data/scripts/build_championship_history").to_s

RSpec.describe "Championship history seeds" do
  before(:context) do
    @root = Rails.root.join("db/seeds/athlete_ace_data")
    @rows = Seeds::BatchClosure.new.rows("championship_history")
    @campaigns = @rows.select { |row| row.type == "Campaign" }
  end

  def import_history
    Dir.mktmpdir do |directory|
      path = File.join(directory, "history.json")
      Seeds::BatchClosure.write(@rows, path)
      first = Seeds::LibraryImporter.new.call([ path ])
      expect(first[:conflicts].all? { |conflict| (conflict.fetch(:differences).keys - %w[conference division]).empty? }).to be(true)
      alignments = Seeds::CampaignAlignmentImporter.new(records: @campaigns).call
      expect(alignments[:conflicts]).to be_empty
      expect(Seeds::LibraryImporter.new.call([ path ])[:conflicts]).to be_empty
      yield path
    end
  end

  it "imports forty sourced titles and finalists, annual classifications, and replays without changes" do
    import_history do |path|
      expect(TitleAward.count).to eq(40)
      expect(Contestant.count).to eq(80)
      expect(Campaign.count).to be >= 1232
      expect(Game.count).to eq(0)
      expect(Appearance.count).to eq(0)
      expect(Membership.count).to eq(0)
      %w[NBA NFL NHL MLB].each do |league|
        titles = TitleAward.joins(:contest).where(contests: { context: League.find_by!(abbreviation: league) })
        expect(titles.count).to eq(10)
        expect(titles.map { |award| award.contest.details.fetch("championship_year") }.sort).to eq((2016..2025).to_a)
        expect(titles.all? { |award| award.source.fetch("url").start_with?("https://") }).to be(true)
        expect(titles.all? { |award| award.winner.placing == 1 && award.contest.runner_up.placing == 2 }).to be(true)
      end
      expect(TitleAward.find_by!(entity_code: "BKT-NBA-SEASON_2024_2025-CHAMPIONSHIP-TITLE").team.name).to eq("Oklahoma City Thunder")
      super_bowl = TitleAward.find_by!(entity_code: "FTB-NFL-SEASON_2015-CHAMPIONSHIP-TITLE")
      expect(super_bowl.team.name).to eq("Denver Broncos")
      expect(super_bowl.awarded_on).to eq(Date.new(2016, 2, 7))
      expect(super_bowl.contest.season.year.number).to eq(2015)
      expect(Campaign.find_by!(entity_code: "FTB-NFL-SEASON_2015-TEAM-LAR").name).to eq("St. Louis Rams")
      expect(Campaign.find_by!(entity_code: "BSB-MLB-SEASON_2016-TEAM-CLE").name).to eq("Cleveland Indians")
      expect(Campaign.find_by!(entity_code: "BSB-MLB-SEASON_2025-TEAM-ATH").name).to eq("Athletics")
      expect(Campaign.find_by!(entity_code: "FTB-NFL-SEASON_2019-TEAM-WAS").name).to eq("Washington Redskins")
      expect(Campaign.find_by!(entity_code: "FTB-NFL-SEASON_2020-TEAM-WAS").name).to eq("Washington Football Team")
      expect(Campaign.find_by!(entity_code: "FTB-NFL-SEASON_2021-TEAM-WAS").name).to eq("Washington Football Team")
      expect(Campaign.find_by!(entity_code: "FTB-NFL-SEASON_2022-TEAM-WAS").name).to eq("Washington Commanders")
      temporary = Campaign.find_by!(entity_code: "HCK-NHL-SEASON_2020_2021-TEAM-STL")
      expect(temporary.division.entity_code).to eq("HCK-NHL-DIVISION-2020_2021-WEST")
      expect(temporary.conference).to be_nil
      restored = Campaign.find_by!(entity_code: "HCK-NHL-SEASON_2021_2022-TEAM-STL")
      expect(restored.division.name).to eq("Central Division")
      expect(restored.conference.name).to eq("Western Conference")
      expect(Team.find_by!(entity_code: "HCK-NHL-TEAM-ARI")).not_to eq(Team.find_by!(entity_code: "HCK-NHL-TEAM-UTA"))
      replay = Seeds::LibraryImporter.new.call([ path ])
      expect(replay[:created]).to be_empty
      expect(replay[:conflicts]).to be_empty
    end
  end

  it "fills missing campaign classifications but preserves and reports recorded disagreements" do
    import_history do
      campaign = Campaign.find_by!(entity_code: "BKT-NBA-SEASON_2020_2021-TEAM-NYK")
      original_division = campaign.division
      campaign.update!(conference: nil, division: nil)
      importer = Seeds::CampaignAlignmentImporter.new(records: @campaigns)
      report = importer.call
      expect(report[:updated]).to eq([ campaign.entity_code ])
      expect(report[:conflicts]).to be_empty
      expect(campaign.reload.division).to eq(original_division)
      expect(importer.call[:updated]).to be_empty
      central = Division.find_by!(entity_code: "BKT-NBA-DIVISION-CENTRAL_DIVISION")
      campaign.update!(division: central)
      report = importer.call
      expect(report[:updated]).to be_empty
      expect(report[:conflicts]).to eq([ { code: campaign.entity_code, fields: [ :division ] } ])
      expect(campaign.reload.division).to eq(central)
    end
  end

  it "rejects reversed, overlapping, incomplete, and historically wrong alignment ranges" do
    Dir.mktmpdir do |directory|
      source = File.join(directory, "sources")
      FileUtils.cp_r(@root.join("sources/championship_history"), source)
      path = File.join(source, "alignment_ranges.yml")
      original = YAML.safe_load(File.read(path))
      cases = [
        [ ->(document) { document.fetch("ranges").first["through"] = 2014 }, /Invalid year range/ ],
        [ ->(document) { document.fetch("ranges") << document.fetch("ranges").first.dup }, /Overlapping/ ],
        [ ->(document) { document.fetch("ranges").shift }, /Incomplete/ ],
        [ ->(document) { document.fetch("ranges").first["division"] = "BKT-NBA-DIVISION-PACIFIC_DIVISION" }, /differs from capture/ ]
      ]
      cases.each do |change, error|
        document = original.deep_dup
        change.call(document)
        File.write(path, YAML.dump(document))
        builder = ChampionshipHistoryBuilder.new(source: source, output: File.join(directory, "output"))
        expect { builder.call }.to raise_error(RuntimeError, error)
      end
      expect(Dir.glob(File.join(directory, "output", "*"))).to be_empty
    end
  end
end
