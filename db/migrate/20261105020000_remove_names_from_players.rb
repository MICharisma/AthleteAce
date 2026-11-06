class RemoveNamesFromPlayers < ActiveRecord::Migration[8.1]
  def up
    missing = select_value "SELECT COUNT(*) FROM players WHERE NOT EXISTS (SELECT 1 FROM people WHERE people.player_id = players.id)"
    raise "#{missing} players have no person to hold their names" if missing.to_i.positive?

    remove_column :players, :first_name
    remove_column :players, :last_name
    remove_column :players, :nicknames
  end

  def down
    add_column :players, :first_name, :string
    add_column :players, :last_name, :string
    add_column :players, :nicknames, :string, array: true, default: []

    execute <<~SQL
      UPDATE players
      SET first_name = people.first_name, last_name = people.last_name, nicknames = people.nicknames
      FROM people
      WHERE people.player_id = players.id
    SQL
  end
end
