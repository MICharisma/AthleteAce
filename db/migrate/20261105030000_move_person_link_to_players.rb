# A person can hold several athletic profiles (two-sport careers), so the
# link moves from people.player_id to players.person_id.
class MovePersonLinkToPlayers < ActiveRecord::Migration[8.1]
  def up
    add_reference :players, :person, foreign_key: true
    execute <<~SQL
      UPDATE players SET person_id = people.id FROM people WHERE people.player_id = players.id
    SQL
    missing = select_value "SELECT COUNT(*) FROM players WHERE person_id IS NULL"
    raise "#{missing} players have no person" if missing.to_i.positive?

    change_column_null :players, :person_id, false
    remove_reference :people, :player, index: { unique: true }, foreign_key: { on_delete: :nullify }
  end

  def down
    shared = select_value "SELECT COUNT(*) FROM (SELECT person_id FROM players GROUP BY person_id HAVING COUNT(*) > 1) shared"
    raise ActiveRecord::IrreversibleMigration, "#{shared} people have several players" if shared.to_i.positive?

    add_reference :people, :player, index: { unique: true }, foreign_key: { on_delete: :nullify }
    execute <<~SQL
      UPDATE people SET player_id = players.id FROM players WHERE players.person_id = people.id
    SQL
    remove_reference :players, :person, foreign_key: true
  end
end
