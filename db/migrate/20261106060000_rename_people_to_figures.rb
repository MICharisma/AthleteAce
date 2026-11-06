class RenamePeopleToFigures < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :players, :people, column: :person_id
    remove_foreign_key :staff_tenures, :people, column: :person_id
    remove_foreign_key :rizz_syncs, :people, column: :person_id

    rename_table :people, :figures
    rename_column :players, :person_id, :figure_id
    rename_column :staff_tenures, :person_id, :figure_id
    rename_column :rizz_syncs, :person_id, :figure_id

    add_foreign_key :players, :figures
    add_foreign_key :staff_tenures, :figures
    add_foreign_key :rizz_syncs, :figures
  end
end
