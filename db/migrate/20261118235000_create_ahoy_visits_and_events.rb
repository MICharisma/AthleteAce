class CreateAhoyVisitsAndEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :ahoy_visits do |t|
      t.string :visit_token, null: false, index: { unique: true }
      t.references :user, foreign_key: { to_table: :aces, on_delete: :nullify }
      t.datetime :started_at, null: false
    end

    create_table :ahoy_events do |t|
      t.references :visit, null: false, foreign_key: { to_table: :ahoy_visits, on_delete: :cascade }
      t.references :user, foreign_key: { to_table: :aces, on_delete: :nullify }
      t.string :name, null: false
      t.jsonb :properties, null: false, default: {}
      t.datetime :time, null: false
      t.index [:name, :time]
    end
  end
end
