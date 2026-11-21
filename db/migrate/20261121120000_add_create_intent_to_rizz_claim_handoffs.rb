class AddCreateIntentToRizzClaimHandoffs < ActiveRecord::Migration[8.1]
  def change
    change_table :rizz_claim_handoffs do |t|
      t.string :intent, null: false, default: "claim"
      t.string :email
      t.string :username
      t.string :display_name
      t.string :encrypted_password
      t.check_constraint "intent IN ('claim', 'create')", name: "rizz_claim_handoffs_intent"
    end

    change_column_null :rizz_claim_receipts, :ace_id, true
    add_reference :rizz_claim_receipts, :rizz_claim_handoff, type: :uuid, foreign_key: { on_delete: :cascade }
    add_check_constraint :rizz_claim_receipts, "ace_id IS NOT NULL OR rizz_claim_handoff_id IS NOT NULL", name: "rizz_claim_receipts_subject"
  end
end
