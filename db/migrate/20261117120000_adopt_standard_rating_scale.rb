class AdoptStandardRatingScale < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM rating_revisions"
    execute "DELETE FROM ratings"
    add_check_constraint :ratings, "value BETWEEN -100 AND 500", name: "ratings_value_in_standard_scale"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The standard scale starts rating data afresh"
  end
end
