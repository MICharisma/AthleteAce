# Names stored by purpose, so names like Yao Ming or Elly De La Cruz don't
# have to fit first + last. Parts remain as input from older seed data.
class AddNameFormsToPeople < ActiveRecord::Migration[8.1]
  def up
    enable_extension "unaccent"
    add_column :people, :short_name, :string
    add_column :people, :sort_name, :string
    add_column :people, :name_segments, :string, array: true, default: [], null: false
    add_column :people, :alternate_names, :string, array: true, default: [], null: false

    execute <<~SQL
      UPDATE people SET
        name_segments = COALESCE(
          NULLIF(ARRAY_REMOVE(ARRAY[NULLIF(BTRIM(first_name), ''), NULLIF(BTRIM(last_name), '')], NULL), '{}'),
          ARRAY[name]),
        short_name = COALESCE(NULLIF(BTRIM(last_name), ''), NULLIF(BTRIM(first_name), ''), name),
        sort_name = COALESCE(NULLIF(CONCAT_WS(', ', NULLIF(BTRIM(last_name), ''), NULLIF(BTRIM(first_name), '')), ''), name)
    SQL
    change_column_null :people, :short_name, false
    change_column_null :people, :sort_name, false
    add_index :people, :sort_name
  end

  def down
    remove_index :people, :sort_name
    remove_column :people, :alternate_names
    remove_column :people, :name_segments
    remove_column :people, :sort_name
    remove_column :people, :short_name
    disable_extension "unaccent"
  end
end
