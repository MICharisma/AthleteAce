# Every game is played somewhere. A contest records its venue when a source
# names it (abroad, neutral sites, college exceptions, or simply the home
# arena); otherwise the home entry's season venue stands in. Home and away
# get a real column, copied from the tiebreakers JSON. The JSON key stays
# until the 2026 coverage manifests can be regenerated without it; removing
# it now would turn every NHL entry into a replay conflict.
class AddVenuesToContests < ActiveRecord::Migration[8.1]
  def up
    add_reference :contests, :stadium, foreign_key: true

    add_column :contestants, :side, :string
    add_check_constraint :contestants, "side IS NULL OR side IN ('home', 'away')", name: "contestants_have_known_sides"
    add_index :contestants, :contest_id, unique: true, where: "side = 'home'", name: "index_contestants_on_contest_home"
    add_index :contestants, :contest_id, unique: true, where: "side = 'away'", name: "index_contestants_on_contest_away"

    execute <<~SQL
      UPDATE contestants
      SET side = tiebreakers::jsonb ->> 'side'
      FROM contests
      WHERE contests.id = contestants.contest_id
        AND contests.type = 'Game'
        AND jsonb_typeof(contestants.tiebreakers::jsonb) = 'object'
        AND contestants.tiebreakers::jsonb ->> 'side' IN ('home', 'away')
    SQL
  end

  def down
    remove_index :contestants, name: "index_contestants_on_contest_away"
    remove_index :contestants, name: "index_contestants_on_contest_home"
    remove_check_constraint :contestants, name: "contestants_have_known_sides"
    remove_column :contestants, :side
    remove_reference :contests, :stadium, foreign_key: true
  end
end
