class CreateRizzSignInTables < ActiveRecord::Migration[8.1]
  def change
    create_table :ace_rizz_bindings, id: :uuid do |t|
      t.references :ace, type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :rizz_sub, null: false
      t.integer :rizz_session_epoch, null: false, default: 1
      t.string :operation_id, null: false
      t.string :status, null: false, default: "active"
      t.datetime :connected_at
      t.datetime :disconnected_at
      t.timestamps
      t.index :rizz_sub, unique: true
      t.index :operation_id, unique: true
      t.index :ace_id, unique: true, where: "status = 'active'", name: "index_ace_rizz_bindings_on_ace_id_active"
      t.check_constraint "status IN ('active', 'disconnected')", name: "ace_rizz_bindings_status"
    end

    create_table :rizz_claim_handoffs, id: :uuid do |t|
      t.string :handoff_jti, null: false
      t.string :operation_id, null: false
      t.string :speaker_label, null: false
      t.string :callback_uri, null: false
      t.string :browser_token_digest, null: false
      t.references :verified_ace, type: :uuid, foreign_key: { to_table: :aces, on_delete: :nullify }
      t.datetime :verified_at
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
      t.index :handoff_jti, unique: true
      t.index :operation_id
    end

    create_table :rizz_claim_receipts, id: :uuid do |t|
      t.string :receipt_digest, null: false
      t.references :ace, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :operation_id, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
      t.index :receipt_digest, unique: true
      t.index :operation_id
    end

    create_table :rizz_backchannel_logout_events, id: :uuid do |t|
      t.string :jti, null: false
      t.string :rizz_sub, null: false
      t.integer :rizz_epoch, null: false
      t.datetime :processed_at, null: false
      t.timestamps
      t.index :jti, unique: true
      t.index :rizz_sub
    end
  end
end
