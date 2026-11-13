# Positions become observations: a roster lists them for a season, an
# appearance records them in game order, and a player may carry a curated
# career summary. Roles (timeless player/position pairs) fold into the
# player-level assignments.
class CreatePositionAssignments < ActiveRecord::Migration[8.1]
  SUBJECT_TYPES = %w[Player RosterEntry Appearance].freeze
  KINDS = %w[position apparatus event weapon].freeze

  def up
    add_column :positions, :entity_code, :string
    add_column :positions, :kind, :string, null: false, default: "position"
    add_reference :positions, :parent, foreign_key: { to_table: :positions }
    add_index :positions, :entity_code, unique: true
    add_check_constraint :positions, "kind IN (#{KINDS.map { "'#{it}'" }.join(', ')})", name: "positions_have_known_kinds"
    add_check_constraint :positions, "parent_id IS NULL OR parent_id <> id", name: "positions_are_not_their_own_parent"

    create_table :position_assignments do |t|
      t.references :subject, polymorphic: true, null: false
      t.references :position, null: false, foreign_key: true
      t.integer :sequence
      t.boolean :primary, null: false, default: false
      t.jsonb :statistics, null: false, default: {}
      t.jsonb :source, null: false, default: {}
      t.jsonb :details, null: false, default: {}
      t.string :entity_code
      t.string :seed_version, comment: "Version of the seed file that created or last updated this record"
      t.datetime :last_seeded_at, comment: "When this record was last updated by a seed"
      t.timestamps

      t.index :entity_code, unique: true
      # A position held twice in one game (LF, then 1B, then LF) needs a sequence.
      t.index %i[subject_type subject_id sequence], unique: true, where: "sequence IS NOT NULL",
        name: "index_position_assignments_on_subject_and_sequence"
      t.index %i[subject_type subject_id position_id], unique: true, where: "sequence IS NULL",
        name: "index_position_assignments_on_subject_and_unsequenced_position"
      t.index %i[subject_type subject_id], unique: true, where: "\"primary\"",
        name: "index_position_assignments_on_subject_primary"
      t.check_constraint "subject_type IN (#{SUBJECT_TYPES.map { "'#{it}'" }.join(', ')})", name: "position_assignments_have_known_subjects"
      t.check_constraint "sequence IS NULL OR sequence > 0", name: "position_assignments_have_positive_sequences"
    end

    execute <<~SQL
      INSERT INTO position_assignments (subject_type, subject_id, position_id, "primary", seed_version, last_seeded_at, created_at, updated_at)
      SELECT 'Player', player_id, position_id, "primary", seed_version, last_seeded_at, created_at, updated_at
      FROM roles
    SQL
    drop_table :roles
  end

  def down
    if select_value("SELECT COUNT(*) FROM position_assignments WHERE subject_type <> 'Player' OR sequence IS NOT NULL").to_i.positive?
      raise ActiveRecord::IrreversibleMigration, "Roster, appearance and sequenced position assignments have no place in roles."
    end

    create_table :roles do |t|
      t.references :player, null: false, foreign_key: true
      t.references :position, null: false, foreign_key: true
      t.boolean :primary, null: false, default: false
      t.timestamps
      t.string :seed_version, comment: "Version of the seed file that created or last updated this record"
      t.datetime :last_seeded_at, comment: "When this record was last updated by a seed"
      t.index %i[player_id position_id], unique: true
      t.index %i[player_id primary]
      t.index :seed_version
    end
    execute <<~SQL
      INSERT INTO roles (player_id, position_id, "primary", seed_version, last_seeded_at, created_at, updated_at)
      SELECT subject_id, position_id, "primary", seed_version, last_seeded_at, created_at, updated_at
      FROM position_assignments
    SQL
    drop_table :position_assignments

    remove_check_constraint :positions, name: "positions_are_not_their_own_parent"
    remove_check_constraint :positions, name: "positions_have_known_kinds"
    remove_index :positions, :entity_code
    remove_reference :positions, :parent, foreign_key: { to_table: :positions }
    remove_column :positions, :kind
    remove_column :positions, :entity_code
  end
end
