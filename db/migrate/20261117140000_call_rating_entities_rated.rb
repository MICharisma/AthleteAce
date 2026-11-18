class CallRatingEntitiesRated < ActiveRecord::Migration[8.1]
  def change
    %i[ratings rating_revisions].each do |table|
      rename_column table, :target_type, :rated_type
      rename_column table, :target_id, :rated_id
      rename_index table, "index_#{table}_on_target", "index_#{table}_on_rated"
    end
    rename_index :ratings, :index_ratings_on_ace_spectrum_and_target_active, :index_ratings_on_ace_spectrum_and_rated_active
  end
end
