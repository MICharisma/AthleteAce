class AddNamesToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :first_name, :string
    add_column :people, :last_name, :string
    add_column :people, :nicknames, :string, array: true, default: [], null: false

    execute <<~SQL
      UPDATE people
      SET first_name = players.first_name,
          last_name = players.last_name,
          nicknames = COALESCE(players.nicknames, '{}'),
          name = COALESCE(NULLIF(CONCAT_WS(' ', NULLIF(BTRIM(players.first_name), ''), NULLIF(BTRIM(players.last_name), '')), ''), people.name)
      FROM players
      WHERE people.player_id = players.id
    SQL
  end

  def down
    remove_column :people, :nicknames
    remove_column :people, :last_name
    remove_column :people, :first_name
  end
end
