class AddMissingForeignKeysForUuidMigration < ActiveRecord::Migration[8.1]
  def up
    # contests.champion_id is a 32-bit integer pointing at teams.id without a foreign key.
    change_column :contests, :champion_id, :bigint
    execute <<~SQL
      UPDATE contests
      SET champion_id = NULL
      WHERE champion_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM teams WHERE teams.id = contests.champion_id)
    SQL
    add_index :contests, :champion_id unless index_exists?(:contests, :champion_id)
    add_foreign_key :contests, :teams, column: :champion_id, on_delete: :nullify unless foreign_key_exists?(:contests, :teams, column: :champion_id)

    # Note:
    # - title_awards.winner_id already participates in the composite foreign key
    #   (contest_id, winner_id) -> contestants(contest_id, id).
    # - rating_revisions.rating_id and rating_revisions.spectrum_id intentionally
    #   do NOT receive foreign keys because Rating#before_destroy writes a "remove"
    #   revision right before deleting the Rating (and Spectrum cascades destroy to ratings).
    #   They are converted directly as non-FK references in the UUIDv7 migration.
  end

  def down
    remove_foreign_key :contests, column: :champion_id if foreign_key_exists?(:contests, :teams, column: :champion_id)
    remove_index :contests, :champion_id if index_exists?(:contests, :champion_id)
    change_column :contests, :champion_id, :integer
  end
end
