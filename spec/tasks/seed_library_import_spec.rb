require "rails_helper"
require "rake"
require "tmpdir"
require "net/http"

RSpec.describe "seeds:import" do
  it "ingests a newly imported pinned file and replays without another download" do
    team = create :team, entity_code: "BKT-NBA-TEAM-HARBOR"
    bytes = '<svg xmlns="http://www.w3.org/2000/svg"><circle r="10"/></svg>'
    reply = Net::HTTPOK.new "1.1", "200", "OK"
    http = instance_double Net::HTTP
    allow(Net::HTTP).to receive(:start).and_yield http
    expect(http).to receive(:request_get).once.with("/MICharisma/athlete_ace_media/#{'a' * 40}/logos/harbor.svg").and_yield reply
    allow(reply).to receive(:read_body).and_yield bytes

    Dir.mktmpdir "seed-library" do |directory|
      root = Pathname.new(directory).join("yaml")
      root.mkpath
      FileUtils.cp Rails.root.join("db/seeds/athlete_ace_data/yaml/entity_sequences.yaml"), root
      root.join("logos.yml").write YAML.dump({ "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => [
        { "type" => "Team", "code" => team.entity_code },
        { "type" => "Logo", "code" => "HARBOR-LOGO", "attributes" => { "name" => "Harbor Athletics mark" }, "references" => { "owner" => team.entity_code } },
        { "type" => "AssetRepresentation", "code" => "HARBOR-LOGO-SVG", "references" => { "subject" => "HARBOR-LOGO" },
          "attributes" => { "canonical_path" => "media/logos/harbor.svg", "file_format" => "svg", "view" => "default", "content_type" => "image/svg+xml",
            "byte_size" => bytes.bytesize, "sha256" => Digest::SHA256.hexdigest(bytes) },
          "source" => { "github" => { "repository" => "MICharisma/athlete_ace_media", "commit" => "a" * 40, "path" => "logos/harbor.svg" } } }
      ] })
      Rails.application.load_tasks unless Rake::Task.task_defined? "seeds:import"
      output = StringIO.new
      original_output, original_root = $stdout, ENV["SEED_LIBRARY_ROOT"]
      begin
        $stdout = output
        ENV["SEED_LIBRARY_ROOT"] = root.to_s
        2.times do
          %w[seeds:import seeds:current_teams seeds:assets:import].each { |name| Rake::Task[name].reenable }
          Rake::Task["seeds:import"].invoke
        end
        expect(AssetRepresentation.sole.file.download).to eq bytes
        expect(ActiveStorage::Attachment.count).to eq 1
        expect(output.string).to include('{"assets":{"imported":1,"unchanged":0}}', '{"assets":{"imported":0,"unchanged":1}}')
      ensure
        AssetRepresentation.find_each { |asset| asset.file.purge }
        $stdout = original_output
        ENV["SEED_LIBRARY_ROOT"] = original_root
      end
    end
  end

  it "gives players created by a fresh import their recorded photos" do
    url = "https://cdn.nba.com/headshots/nba/latest/1040x760/1628973.png"
    Dir.mktmpdir("seed-library") do |directory|
      root = Pathname.new(directory)
      library = root.join("yaml")
      library.mkpath
      FileUtils.cp(Rails.root.join("db/seeds/athlete_ace_data/yaml/entity_sequences.yaml"), library)
      library.join("players.yaml").write(YAML.dump("format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => [
        { "type" => "Sport", "code" => "SPORT-BKT", "attributes" => { "name" => "Basketball" } },
        { "type" => "Player", "code" => "BKT-NBA-PLAYER-BRUNSON_JALEN", "attributes" => { "first_name" => "Jalen", "last_name" => "Brunson" },
          "references" => { "sport" => "SPORT-BKT" } }
      ]))
      root.join("sources").mkpath
      root.join("sources/nba_player_photos.json").write(JSON.generate(players: [
        { code: "BKT-NBA-PLAYER-BRUNSON_JALEN", source_key: "1628973", photo_url: url }
      ]))

      Rails.application.load_tasks unless Rake::Task.task_defined?("seeds:import")
      output = StringIO.new
      original_output, original_root = $stdout, ENV["SEED_LIBRARY_ROOT"]
      begin
        $stdout = output
        ENV["SEED_LIBRARY_ROOT"] = library.to_s
        %w[seeds:import seeds:current_teams seeds:assets:import].each { |name| Rake::Task[name].reenable }
        Rake::Task["seeds:import"].invoke
      ensure
        $stdout = original_output
        ENV["SEED_LIBRARY_ROOT"] = original_root
      end

      expect(Player.find_by!(entity_code: "BKT-NBA-PLAYER-BRUNSON_JALEN").photo_urls).to eq([ url ])
      expect(output.string).to include('{"player_photos":{"updated":0,"unchanged":0,"skipped":1}}', '{"new_player_photos":{"updated":1,"unchanged":0,"skipped":0}}')
    end
  end
end
