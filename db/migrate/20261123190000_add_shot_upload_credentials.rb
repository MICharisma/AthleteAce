class AddShotUploadCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :shot_upload_tokens, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :label, null: false
      t.string :digest, null: false
      t.datetime :revoked_at
      t.timestamps
      t.index :digest, unique: true
    end

    add_reference :shots, :shot_upload_token, type: :uuid, foreign_key: true, index: false
    add_column :shots, :upload_key, :string
    add_column :shots, :upload_fingerprint, :string
    add_index :shots, [:shot_upload_token_id, :upload_key], unique: true
  end
end
