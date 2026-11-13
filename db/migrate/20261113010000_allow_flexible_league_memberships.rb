class AllowFlexibleLeagueMemberships < ActiveRecord::Migration[8.1]
  def up
    add_reference :divisions, :league, foreign_key: true
    add_reference :memberships, :league, foreign_key: true
    add_reference :memberships, :conference, foreign_key: true

    execute <<~SQL
      UPDATE divisions
      SET league_id = conferences.league_id
      FROM conferences
      WHERE divisions.conference_id = conferences.id
    SQL
    execute <<~SQL
      UPDATE memberships
      SET league_id = divisions.league_id, conference_id = divisions.conference_id
      FROM divisions
      WHERE memberships.division_id = divisions.id
    SQL

    change_column_null :divisions, :league_id, false
    change_column_null :divisions, :conference_id, true
    change_column_null :memberships, :league_id, false
    change_column_null :memberships, :division_id, true
  end

  def down
    if select_value("SELECT COUNT(*) FROM divisions WHERE conference_id IS NULL").to_i.positive? ||
        select_value("SELECT COUNT(*) FROM memberships WHERE division_id IS NULL").to_i.positive?
      raise ActiveRecord::IrreversibleMigration, "League-only or conference-only memberships and divisions without conferences cannot use the old hierarchy."
    end

    change_column_null :memberships, :division_id, false
    change_column_null :divisions, :conference_id, false
    remove_reference :memberships, :conference, foreign_key: true
    remove_reference :memberships, :league, foreign_key: true
    remove_reference :divisions, :league, foreign_key: true
  end
end
