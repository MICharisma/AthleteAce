class CreateShotsAndCaptures < ActiveRecord::Migration[8.1]
  def up
    create_table :shots, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.text :external_url
      t.text :tags, array: true, default: [], null: false
      t.timestamps
      t.index :external_url, unique: true
      t.index :tags, using: :gin
    end

    create_table :captures, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :shot, type: :uuid, null: false, foreign_key: true
      t.references :player, type: :uuid, null: false, foreign_key: true, index: false
      t.integer :weight, default: 1, null: false
      t.timestamps
      t.index [:player_id, :shot_id], unique: true
      t.check_constraint "weight >= 0", name: "capture_weight_nonnegative"
    end

    execute <<~SQL
      INSERT INTO shots (external_url, created_at, updated_at)
      SELECT DISTINCT btrim(url), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM players CROSS JOIN LATERAL unnest(photo_urls) AS photos(url)
      WHERE btrim(url) <> '';
    SQL
    execute <<~SQL
      INSERT INTO captures (player_id, shot_id, weight, created_at, updated_at)
      SELECT players.id, shots.id, GREATEST(1, cardinality(photo_urls) - MIN(position) + 1),
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM players CROSS JOIN LATERAL unnest(photo_urls) WITH ORDINALITY AS photos(url, position)
      JOIN shots ON shots.external_url = btrim(photos.url)
      GROUP BY players.id, shots.id;
    SQL
    remove_column :players, :photo_urls
  end

  def down
    add_column :players, :photo_urls, :text, array: true, default: []
    execute <<~SQL
      UPDATE players SET photo_urls = urls.photos
      FROM (
        SELECT player_id, array_agg(shots.external_url ORDER BY weight DESC, shots.external_url) AS photos
        FROM captures JOIN shots ON shots.id = captures.shot_id
        WHERE shots.external_url IS NOT NULL
        GROUP BY player_id
      ) AS urls
      WHERE players.id = urls.player_id;
    SQL
    drop_table :captures
    drop_table :shots
  end
end
