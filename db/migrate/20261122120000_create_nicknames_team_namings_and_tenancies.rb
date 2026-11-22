class CreateNicknamesTeamNamingsAndTenancies < ActiveRecord::Migration[8.1]
  def change
    create_table :nicknames, id: :uuid do |t|
      t.string :text, null: false
      t.string :entity_code
      t.timestamps
      t.index "lower(text)", unique: true, name: "index_nicknames_on_lower_text"
      t.index :entity_code, unique: true
    end

    create_table :team_namings, id: :uuid do |t|
      t.references :team, type: :uuid, null: false, foreign_key: true
      t.references :nickname, type: :uuid, foreign_key: true
      t.string :territory
      t.string :display_name
      t.string :abbreviation
      t.date :start_date
      t.date :end_date
      t.jsonb :source, default: {}, null: false
      t.jsonb :details, default: {}, null: false
      t.string :entity_code
      t.timestamps
      t.index :entity_code, unique: true
      t.check_constraint "start_date IS NULL OR end_date IS NULL OR end_date >= start_date", name: "team_namings_have_ordered_dates"
      t.exclusion_constraint "team_id WITH =, daterange(start_date, end_date, '[]') WITH &&", using: :gist, name: "team_namings_do_not_overlap"
    end

    create_table :tenancies, id: :uuid do |t|
      t.references :team, type: :uuid, null: false, foreign_key: true
      t.references :stadium, type: :uuid, null: false, foreign_key: true
      t.string :role, default: "home", null: false
      t.date :start_date
      t.date :end_date
      t.jsonb :source, default: {}, null: false
      t.jsonb :details, default: {}, null: false
      t.string :entity_code
      t.timestamps
      t.index :entity_code, unique: true
      t.check_constraint "role IN ('home', 'temporary', 'shared')", name: "tenancies_have_known_roles"
      t.check_constraint "start_date IS NULL OR end_date IS NULL OR end_date >= start_date", name: "tenancies_have_ordered_dates"
      t.exclusion_constraint "team_id WITH =, daterange(start_date, end_date, '[]') WITH &&", using: :gist, where: "role = 'home'", name: "home_tenancies_do_not_overlap"
    end
  end
end
