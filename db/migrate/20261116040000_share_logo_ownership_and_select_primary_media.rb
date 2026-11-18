class ShareLogoOwnershipAndSelectPrimaryMedia < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :logos, :teams
    rename_column :logos, :team_id, :owner_id
    add_column :logos, :owner_type, :string, null: false, default: "Team"
    change_column_default :logos, :owner_type, from: "Team", to: nil
    remove_index :logos, :owner_id
    add_index :logos, [:owner_type, :owner_id]
    add_check_constraint :logos, "owner_type IN ('Sport', 'League', 'Conference', 'Division', 'Team')", name: "logo_owner_type"
    %i[sports leagues conferences divisions teams].each do |table|
      add_reference table, :primary_logo, foreign_key: { to_table: :logos, on_delete: :nullify }
    end
    add_reference :figures, :primary_portrait, foreign_key: { to_table: :asset_representations, on_delete: :nullify }
    remove_check_constraint :asset_representations, name: "asset_subject_type"
    add_check_constraint :asset_representations, "subject_type IN ('Logo', 'Uniform', 'UniformPiece', 'Figure')", name: "asset_subject_type"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "League logos and Figure portraits cannot be represented by the old team-only schema."
  end
end
