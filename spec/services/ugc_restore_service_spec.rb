require 'rails_helper'

RSpec.describe UgcRestoreService do
  let(:backup_dir) { Pathname.new(Dir.mktmpdir("ugc_backup")) }

  after { FileUtils.remove_entry(backup_dir) }

  def write_backup(aces:, quests:)
    File.write(backup_dir.join("aces_and_ratings.yml"), { "aces" => aces, "spectrums" => [], "ratings" => [] }.to_yaml)
    File.write(backup_dir.join("quest_system.yml"), { "quests" => quests, "orphaned_achievements" => [] }.to_yaml)
    File.write(backup_dir.join("game_attempts.yml"), { "game_attempts" => [] }.to_yaml)
  end

  def quest_data(name, creator_id)
    { "id" => 1, "name" => name, "description" => "From a backup", "creator_id" => creator_id,
      "achievements" => [], "highlights" => [], "goals" => [] }
  end

  it "maps quest creators through the backup's aces by email" do
    ace = create(:ace)
    # The backup's ids don't match this database's
    write_backup aces: [{ "id" => ace.id + 1000, "email" => ace.email }],
                 quests: [quest_data("Restored Quest", ace.id + 1000)]

    described_class.new(backup_dir).restore_all

    expect(Quest.find_by!(name: "Restored Quest").created_by).to eq(ace)
  end

  it "restores quests without a creator" do
    write_backup aces: [], quests: [quest_data("Seeded Quest", nil)]

    described_class.new(backup_dir).restore_all

    expect(Quest.find_by!(name: "Seeded Quest").created_by).to be_nil
  end

  it "exports entity codes and restores ratings onto the coded player, not a same-name one" do
    team = create(:team)
    create(:player, first_name: "Mike", last_name: "Williams", team: team, entity_code: "FTB-NFL-PLAYER-WILLIAMS_MIKE_1")
    second = create(:player, first_name: "Mike", last_name: "Williams", team: team, entity_code: "FTB-NFL-PLAYER-WILLIAMS_MIKE_2")
    rating = create(:rating, target: second)
    UgcBackupService.new(backup_dir).backup_all
    exported = YAML.load_file(backup_dir.join("aces_and_ratings.yml"), permitted_classes: [Time, Date, Symbol, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone], aliases: true)
    expect(exported.fetch(:ratings).sole).to include("target_code" => "FTB-NFL-PLAYER-WILLIAMS_MIKE_2", "target_identifier" => "Mike Williams")
    rating.delete

    described_class.new(backup_dir).restore_all

    expect(Rating.sole.target).to eq(second)
  end

  it "follows a code's alias and still restores by name when a backup has no code" do
    player = create(:player, first_name: "Jalen", last_name: "Brunson", entity_code: "BKT-NBA-PLAYER-BRUNSON_JALEN")
    EntityCode.create!(namespace: "MIC", catalog: "ALA", code: "BKT-NBA-NYK-2022-BRUNSON_JALEN", canonical_code: player.entity_code, record: player)
    ace = create(:ace)
    spectrum = create(:spectrum)
    rating = { "ace_id" => 1, "spectrum_id" => 2, "target_type" => "Player", "value" => 50, "created_at" => 1.day.ago }
    File.write(backup_dir.join("aces_and_ratings.yml"), {
      "aces" => [{ "id" => 1, "email" => ace.email }],
      "spectrums" => [spectrum.attributes.merge("id" => 2)],
      "ratings" => [rating.merge("target_code" => "BKT-NBA-NYK-2022-BRUNSON_JALEN"),
                    rating.merge("target_identifier" => "Jalen Brunson", "created_at" => 2.days.ago)]
    }.to_yaml)
    File.write(backup_dir.join("quest_system.yml"), { "quests" => [], "orphaned_achievements" => [] }.to_yaml)
    File.write(backup_dir.join("game_attempts.yml"), { "game_attempts" => [] }.to_yaml)

    described_class.new(backup_dir).restore_all

    expect(Rating.where(target: player).count).to eq(2)
  end
end
