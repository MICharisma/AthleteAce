class ConvertFollowsToEngagements < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :follows, name: "follows_supported_type"
    remove_index :follows, [ :ace_id, :followable_type, :followable_id ]
    remove_index :follows, [ :followable_type, :followable_id ]
    remove_index :follows, :ace_id

    rename_table :follows, :engagements
    rename_column :engagements, :ace_id, :actor_id
    rename_column :engagements, :followable_type, :engageable_type
    rename_column :engagements, :followable_id, :engageable_id
    add_column :engagements, :actor_type, :string, null: false, default: "Ace"
    add_column :engagements, :kind, :string, null: false, default: "follow"
    change_column_default :engagements, :actor_type, nil
    change_column_default :engagements, :kind, nil

    add_index :engagements, %i[engageable_type engageable_id kind], name: "index_engagements_on_record_and_kind"
    add_index :engagements, %i[actor_type actor_id engageable_type engageable_id kind],
      unique: true, name: "index_engagements_once_per_actor_record_and_kind"
    add_index :engagements, %i[actor_type actor_id], name: "index_engagements_on_actor"
    add_check_constraint :engagements, "kind IN ('bookmark', 'favorite', 'follow', 'hide')", name: "engagements_kind_is_known"
  end

  def down
    if select_value("SELECT EXISTS (SELECT 1 FROM engagements WHERE kind <> 'follow' OR actor_type <> 'Ace' OR engageable_type NOT IN ('Player', 'Team'))")
      raise ActiveRecord::IrreversibleMigration, "Rolling back would discard engagements"
    end

    remove_check_constraint :engagements, name: "engagements_kind_is_known"
    remove_index :engagements, name: "index_engagements_on_record_and_kind"
    remove_index :engagements, name: "index_engagements_once_per_actor_record_and_kind"
    remove_index :engagements, name: "index_engagements_on_actor"
    remove_column :engagements, :kind
    remove_column :engagements, :actor_type
    rename_column :engagements, :actor_id, :ace_id
    rename_column :engagements, :engageable_type, :followable_type
    rename_column :engagements, :engageable_id, :followable_id
    rename_table :engagements, :follows

    add_index :follows, :ace_id
    add_index :follows, [ :followable_type, :followable_id ], name: "index_follows_on_followable"
    add_index :follows, [ :ace_id, :followable_type, :followable_id ], unique: true
    add_check_constraint :follows, "followable_type IN ('Team', 'Player')", name: "follows_supported_type"
  end
end
