require "rails_helper"
require "tmpdir"
require Rails.root.join("db/seeds/athlete_ace_data/scripts/build_team_namings").to_s

RSpec.describe TeamNamingsBuilder do
  def library(directory, seasons:, campaigns:)
    yaml = File.join(directory, "yaml")
    FileUtils.mkdir_p(yaml)
    records = [
      { "type" => "Team", "code" => "BKT-NBA-TEAM-OKC", "attributes" => { "territory" => "Oklahoma City", "mascot" => "Thunder" }, "references" => {}, "scope" => { "league" => "BKT-LEAGUE-NBA" } },
      { "type" => "Team", "code" => "BKT-NBA-TEAM-NOP", "attributes" => { "territory" => "New Orleans", "mascot" => "Pelicans" }, "references" => {}, "scope" => { "league" => "BKT-LEAGUE-NBA" } }
    ] + seasons.map do |label, start_date|
      year = label.to_i
      { "type" => "Season", "code" => "BKT-NBA-SEASON_#{label}", "attributes" => { "label" => label, "start_date" => start_date }.compact,
        "references" => { "year" => "YEAR-#{year}" }, "scope" => { "league" => "BKT-LEAGUE-NBA" } }
    end + campaigns.map do |label, team, display_name, abbreviation|
      { "type" => "Campaign", "code" => "BKT-NBA-SEASON_#{label}-TEAM-#{team}", "attributes" => { "display_name" => display_name, "abbreviation" => abbreviation },
        "references" => { "team" => "BKT-NBA-TEAM-#{team}", "year" => "YEAR-#{label.to_i}" }, "scope" => { "league" => "BKT-LEAGUE-NBA" } }
    end
    File.write(File.join(yaml, "library.yml"), YAML.dump("format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records))
    yaml
  end

  let(:seasons) { { "2007_2008" => "2007-10-30", "2008_2009" => "2008-10-28", "2009_2010" => "2009-10-27" } }
  let(:campaigns) do
    [ [ "2007_2008", "OKC", "Seattle SuperSonics", "SEA" ], [ "2008_2009", "OKC", "Oklahoma City Thunder", "OKC" ], [ "2009_2010", "OKC", "Oklahoma City Thunder", "OKC" ],
      [ "2007_2008", "NOP", "New Orleans Hornets", "NOH" ], [ "2008_2009", "NOP", "New Orleans Hornets", "NOH" ], [ "2009_2010", "NOP", "New Orleans Hornets", "NOH" ] ]
  end

  it "turns runs of seasons under one name into dated namings that import and replay" do
    Dir.mktmpdir do |directory|
      nicknames = File.join(directory, "nicknames.yml")
      File.write(nicknames, YAML.dump("nicknames" => [ { "text" => "SuperSonics" }, { "text" => "Hornets" } ]))
      output = File.join(directory, "out/team_namings.yml")
      builder = described_class.new(library: library(directory, seasons: seasons, campaigns: campaigns), output: output, nicknames: nicknames, leagues: %w[BKT-LEAGUE-NBA])
      builder.call
      expect(builder.unsplit).to be_empty

      league = create :league, entity_code: "BKT-LEAGUE-NBA"
      thunder = create :team, league: league, entity_code: "BKT-NBA-TEAM-OKC", territory: "Oklahoma City", mascot: "Thunder"
      create :team, league: league, entity_code: "BKT-NBA-TEAM-NOP", territory: "New Orleans", mascot: "Pelicans"
      expect(Seeds::LibraryImporter.new.call([ output ])[:conflicts]).to be_empty

      sonics, okc = thunder.team_namings.chronological.to_a
      expect(sonics.attributes.slice("territory", "abbreviation", "display_name")).to eq("territory" => "Seattle", "abbreviation" => "SEA", "display_name" => nil)
      expect([ sonics.start_date, sonics.end_date ]).to eq([ Date.new(2007, 10, 30), Date.new(2008, 10, 27) ])
      expect([ okc.start_date, okc.end_date ]).to eq([ Date.new(2008, 10, 28), nil ])
      expect(sonics.details).to include("bounds" => "season_level", "first_season" => "BKT-NBA-SEASON_2007_2008", "last_season" => "BKT-NBA-SEASON_2007_2008")
      expect(thunder.name_on(Date.new(2008, 1, 1))).to eq("Seattle SuperSonics")
      expect(Nickname.pluck(:text)).to contain_exactly("SuperSonics", "Thunder", "Hornets")
      expect(Seeds::LibraryImporter.new.call([ output ])[:created]).to be_empty
      expect { described_class.new(check: true, library: File.join(directory, "yaml"), output: output, nicknames: nicknames, leagues: %w[BKT-LEAGUE-NBA]).call }.not_to raise_error
    end
  end

  it "keeps a name with no known nickname whole" do
    Dir.mktmpdir do |directory|
      output = File.join(directory, "out/team_namings.yml")
      builder = described_class.new(library: library(directory, seasons: seasons, campaigns: campaigns), output: output, nicknames: File.join(directory, "none.yml"), leagues: %w[BKT-LEAGUE-NBA])
      builder.call
      expect(builder.unsplit.uniq).to contain_exactly("Seattle SuperSonics", "New Orleans Hornets")
      sonics = YAML.safe_load(File.read(output)).fetch("records").find { it["code"] == "BKT-NBA-TEAM-OKC-NAMING-2007_2008" }
      expect(sonics.fetch("attributes")).to include("display_name" => "Seattle SuperSonics")
      expect(sonics.fetch("references")).not_to have_key("nickname")
    end
  end

  it "refuses seasons without a start date and campaigns named by abbreviation" do
    Dir.mktmpdir do |directory|
      undated = library(directory, seasons: seasons.merge("2009_2010" => nil), campaigns: campaigns)
      expect { described_class.new(library: undated, output: File.join(directory, "out/a.yml"), leagues: %w[BKT-LEAGUE-NBA]).call }
        .to raise_error(RuntimeError, /Seasons without a start date: BKT-NBA-SEASON_2009_2010/)
    end
    Dir.mktmpdir do |directory|
      abbreviated = library(directory, seasons: seasons, campaigns: campaigns.map { it[0..1] == [ "2009_2010", "OKC" ] ? [ "2009_2010", "OKC", "OKC", "OKC" ] : it })
      expect { described_class.new(library: abbreviated, output: File.join(directory, "out/a.yml"), leagues: %w[BKT-LEAGUE-NBA]).call }
        .to raise_error(RuntimeError, /display name is an abbreviation: BKT-NBA-SEASON_2009_2010-TEAM-OKC/)
    end
  end
end
