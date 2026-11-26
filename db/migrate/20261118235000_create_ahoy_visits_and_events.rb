class CreateAhoyVisitsAndEvents < ActiveRecord::Migration[8.1]
  def change
    ace_id = connection.columns(:aces).find { |column| column.name == "id" }
    key_type = ace_id.type == :uuid ? :uuid : :bigint

    create_table :ahoy_visits, id: key_type do |t|
      t.string :visit_token, null: false, index: { unique: true }
      t.references :user, type: key_type, foreign_key: { to_table: :aces, on_delete: :nullify }
      t.datetime :started_at, null: false
    end

    create_table :ahoy_events, id: key_type do |t|
      t.references :visit, type: key_type, null: false, foreign_key: { to_table: :ahoy_visits, on_delete: :cascade }
      t.references :user, type: key_type, foreign_key: { to_table: :aces, on_delete: :nullify }
      t.string :name, null: false
      t.jsonb :properties, null: false, default: {}
      t.datetime :time, null: false
      t.index [:name, :time]
    end
  end
end
