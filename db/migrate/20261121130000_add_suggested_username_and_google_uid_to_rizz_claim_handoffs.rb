class AddSuggestedUsernameAndGoogleUidToRizzClaimHandoffs < ActiveRecord::Migration[8.1]
  def change
    change_table :rizz_claim_handoffs do |t|
      t.string :suggested_username
      t.string :google_uid
    end
  end
end
