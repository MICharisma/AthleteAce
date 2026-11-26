class CreateCreditGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_grants, id: :uuid do |t|
      t.references :ace, type: :uuid, null: false, foreign_key: true
      t.references :actor, type: :uuid, foreign_key: { to_table: :aces, on_delete: :nullify }
      t.bigint :amount_cents, null: false
      t.string :reason, null: false
      t.timestamps
      t.check_constraint "amount_cents > 0", name: "credit_grants_positive_amount"
    end
  end
end
