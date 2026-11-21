# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_21_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "unaccent"

  create_table "account_actions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "ace_name", null: false
    t.string "action", null: false
    t.text "reason", null: false
    t.jsonb "before_state", null: false
    t.jsonb "after_state", null: false
    t.string "request_key", limit: 128, null: false
    t.datetime "created_at", null: false
    t.uuid "ace_id"
    t.uuid "actor_id"
    t.index ["ace_id"], name: "index_account_actions_on_ace_id"
    t.index ["actor_id", "request_key"], name: "index_account_actions_on_actor_id_and_request_key", unique: true
    t.index ["actor_id"], name: "index_account_actions_on_actor_id"
  end

  create_table "ace_rizz_bindings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ace_id", null: false
    t.string "rizz_sub", null: false
    t.integer "rizz_session_epoch", default: 1, null: false
    t.string "operation_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "connected_at"
    t.datetime "disconnected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ace_id"], name: "index_ace_rizz_bindings_on_ace_id_active", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["operation_id"], name: "index_ace_rizz_bindings_on_operation_id", unique: true
    t.index ["rizz_sub"], name: "index_ace_rizz_bindings_on_rizz_sub", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'disconnected'::character varying]::text[])", name: "ace_rizz_bindings_status"
  end

  create_table "aces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "moderator", default: false, null: false
    t.string "theme", default: "system", null: false
    t.string "username"
    t.string "display_name"
    t.string "avatar_color", default: "#7A4B2A", null: false
    t.string "time_zone"
    t.datetime "suspended_at"
    t.integer "account_version", default: 0, null: false
    t.integer "session_version", default: 0, null: false
    t.string "google_uid"
    t.index "lower((username)::text)", name: "index_aces_on_lower_username", unique: true
    t.index ["confirmation_token"], name: "index_aces_on_confirmation_token", unique: true
    t.index ["email"], name: "index_aces_on_email", unique: true
    t.index ["google_uid"], name: "index_aces_on_google_uid", unique: true, where: "(google_uid IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_aces_on_reset_password_token", unique: true
    t.check_constraint "theme::text = ANY (ARRAY['light'::character varying, 'dark'::character varying, 'system'::character varying]::text[])", name: "aces_theme"
  end

  create_table "achievements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "target_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.json "details"
    t.string "moderation_status", default: "approved", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "created_by_id"
    t.uuid "target_id", null: false
    t.index ["created_by_id"], name: "index_achievements_on_created_by_id"
    t.index ["moderation_status", "created_at"], name: "index_achievements_on_moderation_status_and_created_at"
    t.index ["seed_version"], name: "index_achievements_on_seed_version"
    t.index ["target_type", "target_id"], name: "index_achievements_on_target"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'hidden'::character varying]::text[])", name: "achievements_moderation_status"
  end

  create_table "activations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.json "details"
    t.string "seed_version"
    t.datetime "last_seeded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_code"
    t.uuid "campaign_id", null: false
    t.uuid "contract_id"
    t.uuid "player_id", null: false
    t.index ["campaign_id"], name: "index_activations_on_campaign_id"
    t.index ["contract_id"], name: "index_activations_on_contract_id"
    t.index ["entity_code"], name: "index_activations_on_entity_code", unique: true
    t.index ["player_id", "campaign_id"], name: "index_activations_on_player_id_and_campaign_id", unique: true
    t.index ["player_id"], name: "index_activations_on_player_id"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.datetime "created_at", null: false
    t.uuid "blob_id", null: false
    t.uuid "record_id", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "variation_digest", null: false
    t.uuid "blob_id", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appearances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "starter"
    t.string "jersey_number"
    t.jsonb "statistics", default: {}, null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "contestant_id", null: false
    t.uuid "player_id", null: false
    t.uuid "stint_id"
    t.index ["contestant_id", "player_id"], name: "index_appearances_on_contestant_id_and_player_id", unique: true
    t.index ["contestant_id"], name: "index_appearances_on_contestant_id"
    t.index ["entity_code"], name: "index_appearances_on_entity_code", unique: true
    t.index ["player_id"], name: "index_appearances_on_player_id"
    t.index ["stint_id"], name: "index_appearances_on_stint_id"
  end

  create_table "asset_representations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subject_type", null: false
    t.string "file_format", null: false
    t.string "view", default: "default", null: false
    t.string "canonical_path", null: false
    t.string "content_type", null: false
    t.string "sha256", null: false
    t.bigint "byte_size", null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "subject_id", null: false
    t.index ["entity_code"], name: "index_asset_representations_on_entity_code", unique: true
    t.index ["subject_type", "subject_id", "file_format", "view"], name: "unique_asset_representation", unique: true
    t.index ["subject_type", "subject_id"], name: "index_asset_representations_on_subject"
    t.check_constraint "byte_size > 0", name: "asset_file_not_empty"
    t.check_constraint "sha256::text ~ '^[a-f0-9]{64}$'::text", name: "asset_sha256_format"
    t.check_constraint "subject_type::text = ANY (ARRAY['Logo'::character varying, 'Uniform'::character varying, 'UniformPiece'::character varying, 'Figure'::character varying]::text[])", name: "asset_subject_type"
  end

  create_table "attestations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "claim_type", null: false
    t.string "content_form", null: false
    t.text "body"
    t.string "url"
    t.string "media_url"
    t.text "excerpt"
    t.string "locator"
    t.string "author_name"
    t.string "source_title"
    t.string "publisher"
    t.string "published_on"
    t.datetime "captured_at"
    t.text "context"
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "author_id"
    t.uuid "entered_by_id"
    t.uuid "claim_id", null: false
    t.index ["author_id"], name: "index_attestations_on_author_id"
    t.index ["claim_type", "claim_id"], name: "index_attestations_on_claim"
    t.index ["entered_by_id"], name: "index_attestations_on_entered_by_id"
    t.index ["entity_code"], name: "index_attestations_on_entity_code", unique: true
    t.check_constraint "claim_type::text = ANY (ARRAY['FigureBusinessRelationship'::character varying, 'FigurePracticeRelationship'::character varying, 'AttributedStatement'::character varying]::text[])", name: "attestations_claim_type"
    t.check_constraint "content_form::text = ANY (ARRAY['text'::character varying, 'link'::character varying, 'image'::character varying, 'video'::character varying]::text[])", name: "attestations_content_form"
  end

  create_table "attributed_statements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "attribution_kind", null: false
    t.text "text", null: false
    t.string "observer_name"
    t.string "statement_date"
    t.text "context"
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "moderation_status", default: "pending", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.string "revision_transaction"
    t.uuid "figure_id", null: false
    t.uuid "figure_practice_relationship_id"
    t.uuid "observer_id"
    t.uuid "staff_tenure_id"
    t.uuid "topic_id"
    t.index ["entity_code"], name: "index_attributed_statements_on_entity_code", unique: true
    t.index ["figure_id"], name: "index_attributed_statements_on_figure_id"
    t.index ["figure_practice_relationship_id"], name: "index_attributed_statements_on_figure_practice_relationship_id"
    t.index ["moderation_status"], name: "index_attributed_statements_on_moderation_status"
    t.index ["observer_id"], name: "index_attributed_statements_on_observer_id"
    t.index ["staff_tenure_id"], name: "index_attributed_statements_on_staff_tenure_id"
    t.index ["topic_id"], name: "index_attributed_statements_on_topic_id"
    t.check_constraint "attribution_kind::text = ANY (ARRAY['direct_quote'::character varying, 'attributed_paraphrase'::character varying, 'self_stated_value'::character varying, 'observer_characterization'::character varying]::text[])", name: "attributed_statements_attribution_kind"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'hidden'::character varying]::text[])", name: "attributed_statements_moderation_status"
  end

  create_table "businesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "url"
    t.integer "founded_year"
    t.text "description"
    t.string "entity_code", null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_code"], name: "index_businesses_on_entity_code", unique: true
    t.index ["name"], name: "index_businesses_on_name"
  end

  create_table "campaigns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "comments", default: [], comment: "Array of comments about the campaign", array: true
    t.string "seed_version", comment: "Version when this record was seeded"
    t.datetime "last_seeded_at", comment: "When this record was last seeded"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name"
    t.string "territory"
    t.string "mascot"
    t.string "abbreviation"
    t.string "logo_url"
    t.string "primary_color"
    t.string "secondary_color"
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.uuid "city_id"
    t.uuid "conference_id"
    t.uuid "division_id"
    t.uuid "season_id", null: false
    t.uuid "stadium_id"
    t.uuid "team_id", null: false
    t.index ["city_id"], name: "index_campaigns_on_city_id"
    t.index ["conference_id"], name: "index_campaigns_on_conference_id"
    t.index ["division_id"], name: "index_campaigns_on_division_id"
    t.index ["entity_code"], name: "index_campaigns_on_entity_code", unique: true
    t.index ["season_id"], name: "index_campaigns_on_season_id"
    t.index ["stadium_id"], name: "index_campaigns_on_stadium_id"
    t.index ["team_id", "season_id"], name: "index_campaigns_on_team_id_and_season_id", unique: true
    t.index ["team_id"], name: "index_campaigns_on_team_id"
  end

  create_table "catalog_edits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor_name", null: false
    t.string "record_type", null: false
    t.string "entity_code"
    t.string "record_name", null: false
    t.jsonb "before_values", null: false
    t.jsonb "after_values", null: false
    t.jsonb "submitted_values", null: false
    t.string "request_key", limit: 128, null: false
    t.text "reason"
    t.datetime "reason_supplied_at"
    t.datetime "created_at", null: false
    t.uuid "actor_id"
    t.uuid "record_id", null: false
    t.index ["actor_id", "request_key"], name: "index_catalog_edits_on_actor_id_and_request_key", unique: true
    t.index ["actor_id"], name: "index_catalog_edits_on_actor_id"
    t.index ["id"], name: "index_catalog_edits_without_reason", where: "(reason IS NULL)"
    t.index ["record_type", "record_id", "id"], name: "index_catalog_edits_on_record_type_and_record_id_and_id"
    t.check_constraint "reason IS NULL AND reason_supplied_at IS NULL OR reason IS NOT NULL AND length(btrim(reason)) >= 1 AND length(btrim(reason)) <= 2000 AND reason_supplied_at IS NOT NULL", name: "catalog_edit_reason"
    t.check_constraint "record_type::text = ANY (ARRAY['Player'::character varying, 'Team'::character varying]::text[])", name: "catalog_edit_record_type"
  end

  create_table "cities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "state_id", null: false
    t.index ["entity_code"], name: "index_cities_on_entity_code", unique: true
    t.index ["seed_version"], name: "index_cities_on_seed_version"
    t.index ["state_id"], name: "index_cities_on_state_id"
  end

  create_table "conferences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbreviation"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "league_id", null: false
    t.uuid "primary_logo_id"
    t.index ["entity_code"], name: "index_conferences_on_entity_code", unique: true
    t.index ["league_id"], name: "index_conferences_on_league_id"
    t.index ["primary_logo_id"], name: "index_conferences_on_primary_logo_id"
    t.index ["seed_version"], name: "index_conferences_on_seed_version"
  end

  create_table "contest_games", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "metadata", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "contest_id", null: false
    t.uuid "game_id", null: false
    t.index ["contest_id", "game_id"], name: "index_contest_games_on_contest_id_and_game_id", unique: true
    t.index ["contest_id"], name: "index_contest_games_on_contest_id"
    t.index ["entity_code"], name: "index_contest_games_on_entity_code", unique: true
    t.index ["game_id"], name: "index_contest_games_on_game_id"
    t.index ["metadata"], name: "index_contest_games_on_metadata", using: :gin
    t.check_constraint "contest_id <> game_id", name: "game_cannot_contain_itself"
    t.check_constraint "jsonb_typeof(metadata) = 'object'::text", name: "contest_game_metadata_is_object"
  end

  create_table "contestants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "placing"
    t.integer "wins"
    t.integer "losses"
    t.json "tiebreakers"
    t.string "seed_version"
    t.datetime "last_seeded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_code"
    t.string "side"
    t.uuid "campaign_id", null: false
    t.uuid "contest_id", null: false
    t.index ["campaign_id"], name: "index_contestants_on_campaign_id"
    t.index ["contest_id", "campaign_id"], name: "index_contestants_on_contest_id_and_campaign_id", unique: true
    t.index ["contest_id", "id"], name: "index_contestants_on_contest_id_and_id", unique: true
    t.index ["contest_id"], name: "index_contestants_on_contest_away", unique: true, where: "((side)::text = 'away'::text)"
    t.index ["contest_id"], name: "index_contestants_on_contest_home", unique: true, where: "((side)::text = 'home'::text)"
    t.index ["contest_id"], name: "index_contestants_on_contest_id"
    t.index ["entity_code"], name: "index_contestants_on_entity_code", unique: true
    t.check_constraint "side IS NULL OR (side::text = ANY (ARRAY['home'::character varying, 'away'::character varying]::text[]))", name: "contestants_have_known_sides"
  end

  create_table "contests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "context_type", null: false
    t.date "begin_date"
    t.date "end_date"
    t.text "comments"
    t.jsonb "details"
    t.string "seed_version"
    t.datetime "last_seeded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_code"
    t.string "kind"
    t.string "type"
    t.jsonb "format_rules", default: {}, null: false
    t.uuid "champion_id"
    t.uuid "season_id"
    t.uuid "stadium_id"
    t.uuid "context_id", null: false
    t.index ["champion_id"], name: "index_contests_on_champion_id"
    t.index ["context_type", "context_id"], name: "index_contests_on_context"
    t.index ["entity_code"], name: "index_contests_on_entity_code", unique: true
    t.index ["kind", "begin_date"], name: "index_contests_on_kind_and_begin_date"
    t.index ["season_id"], name: "index_contests_on_season_id"
    t.index ["stadium_id"], name: "index_contests_on_stadium_id"
    t.index ["type"], name: "index_contests_on_type"
    t.check_constraint "jsonb_typeof(format_rules) = 'object'::text", name: "contest_format_is_object"
    t.check_constraint "type IS NOT NULL AND kind IS NOT NULL AND type::text = 'Game'::text AND kind::text = 'game'::text OR type IS NULL AND kind::text IS DISTINCT FROM 'game'::text", name: "contest_game_type"
  end

  create_table "contracts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.decimal "total_dollar_value"
    t.json "details"
    t.string "seed_version"
    t.datetime "last_seeded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_code"
    t.uuid "organization_id", null: false
    t.uuid "player_id", null: false
    t.uuid "team_id"
    t.index ["entity_code"], name: "index_contracts_on_entity_code", unique: true
    t.index ["organization_id"], name: "index_contracts_on_organization_id"
    t.index ["player_id"], name: "index_contracts_on_player_id"
    t.index ["team_id"], name: "index_contracts_on_team_id"
  end

  create_table "countries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbreviation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "flag_url"
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.index ["entity_code"], name: "index_countries_on_entity_code", unique: true
    t.index ["seed_version"], name: "index_countries_on_seed_version"
  end

  create_table "credit_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "available_cents", default: 0, null: false
    t.bigint "reserved_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.index ["ace_id"], name: "index_credit_accounts_on_ace_id", unique: true
    t.check_constraint "available_cents >= 0 AND reserved_cents >= 0", name: "credit_nonnegative"
  end

  create_table "credit_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "source_type", null: false
    t.string "operation_key", null: false
    t.string "kind", null: false
    t.bigint "available_delta", null: false
    t.bigint "reserved_delta", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "credit_account_id", null: false
    t.uuid "source_id", null: false
    t.index ["credit_account_id"], name: "index_credit_entries_on_credit_account_id"
    t.index ["operation_key"], name: "index_credit_entries_on_operation_key", unique: true
    t.index ["source_type", "source_id"], name: "index_credit_entries_on_source"
  end

  create_table "decision_evaluations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subject_type"
    t.integer "revision"
    t.string "comparison_key", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "purpose", null: false
    t.string "policy_version", null: false
    t.string "status", default: "queued", null: false
    t.string "choice"
    t.string "error_code"
    t.jsonb "request_snapshot", default: {}, null: false
    t.jsonb "answer", default: {}, null: false
    t.bigint "input_tokens"
    t.decimal "input_usd_per_million", precision: 12, scale: 6, null: false
    t.decimal "estimated_usd", precision: 20, scale: 10
    t.integer "latency_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "subject_id"
    t.index ["comparison_key", "provider"], name: "index_decision_evaluations_on_comparison_key_and_provider", unique: true
    t.index ["subject_type", "subject_id"], name: "index_decision_evaluations_on_subject"
  end

  create_table "divisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbreviation"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "conference_id"
    t.uuid "league_id", null: false
    t.uuid "primary_logo_id"
    t.index ["conference_id"], name: "index_divisions_on_conference_id"
    t.index ["entity_code"], name: "index_divisions_on_entity_code", unique: true
    t.index ["league_id"], name: "index_divisions_on_league_id"
    t.index ["primary_logo_id"], name: "index_divisions_on_primary_logo_id"
    t.index ["seed_version"], name: "index_divisions_on_seed_version"
  end

  create_table "entity_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "namespace", null: false
    t.string "catalog", null: false
    t.string "code", null: false
    t.string "canonical_code", null: false
    t.string "record_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "record_id"
    t.index ["namespace", "catalog", "canonical_code"], name: "index_entity_codes_on_namespace_and_catalog_and_canonical_code"
    t.index ["namespace", "catalog", "code"], name: "index_entity_codes_on_namespace_and_catalog_and_code", unique: true
    t.index ["record_type", "record_id"], name: "index_entity_codes_on_record"
  end

  create_table "federations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbreviation"
    t.text "description"
    t.string "url"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.index ["entity_code"], name: "index_federations_on_entity_code", unique: true
    t.index ["seed_version"], name: "index_federations_on_seed_version"
  end

  create_table "figure_business_relationships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "predicate", null: false
    t.string "start_date"
    t.string "end_date"
    t.string "temporal_state", default: "unknown", null: false
    t.string "as_of_date"
    t.string "compensation", default: "unknown", null: false
    t.text "compensation_description"
    t.string "vehicle_name"
    t.text "context"
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "moderation_status", default: "pending", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.string "revision_transaction"
    t.uuid "business_id", null: false
    t.uuid "figure_id", null: false
    t.index ["business_id"], name: "index_figure_business_relationships_on_business_id"
    t.index ["entity_code"], name: "index_figure_business_relationships_on_entity_code", unique: true
    t.index ["figure_id"], name: "index_figure_business_relationships_on_figure_id"
    t.index ["moderation_status"], name: "index_figure_business_relationships_on_moderation_status"
    t.check_constraint "compensation::text = ANY (ARRAY['documented_paid'::character varying, 'documented_unpaid'::character varying, 'unknown'::character varying]::text[])", name: "figure_business_relationships_compensation"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'hidden'::character varying]::text[])", name: "figure_business_relationships_moderation_status"
    t.check_constraint "predicate::text = ANY (ARRAY['founded'::character varying, 'owns'::character varying, 'invests_in'::character varying, 'endorses'::character varying, 'promotes'::character varying, 'sponsored_by'::character varying]::text[])", name: "figure_business_relationships_predicate"
    t.check_constraint "temporal_state::text = ANY (ARRAY['reported_current'::character varying, 'historical'::character varying, 'planned'::character varying, 'unknown'::character varying]::text[])", name: "figure_business_relationships_temporal_state"
  end

  create_table "figure_practice_relationships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "predicate", null: false
    t.text "interpretation"
    t.string "start_date"
    t.string "end_date"
    t.string "temporal_state", default: "unknown", null: false
    t.string "as_of_date"
    t.text "context"
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "moderation_status", default: "pending", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.string "revision_transaction"
    t.uuid "figure_id", null: false
    t.uuid "protocol_id"
    t.index ["entity_code"], name: "index_figure_practice_relationships_on_entity_code", unique: true
    t.index ["figure_id"], name: "index_figure_practice_relationships_on_figure_id"
    t.index ["moderation_status"], name: "index_figure_practice_relationships_on_moderation_status"
    t.index ["protocol_id"], name: "index_figure_practice_relationships_on_protocol_id"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'hidden'::character varying]::text[])", name: "figure_practice_relationships_moderation_status"
    t.check_constraint "predicate::text = ANY (ARRAY['participates_in'::character varying, 'recommends'::character varying, 'teaches'::character varying, 'endorses'::character varying]::text[])", name: "figure_practice_relationships_predicate"
    t.check_constraint "temporal_state::text = ANY (ARRAY['reported_current'::character varying, 'historical'::character varying, 'planned'::character varying, 'unknown'::character varying]::text[])", name: "figure_practice_relationships_temporal_state"
  end

  create_table "figures", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "entity_code", null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "nicknames", default: [], null: false, array: true
    t.string "short_name", null: false
    t.string "sort_name", null: false
    t.string "name_segments", default: [], null: false, array: true
    t.string "alternate_names", default: [], null: false, array: true
    t.uuid "primary_portrait_id"
    t.index ["entity_code"], name: "index_figures_on_entity_code", unique: true
    t.index ["primary_portrait_id"], name: "index_figures_on_primary_portrait_id"
    t.index ["sort_name"], name: "index_figures_on_sort_name"
  end

  create_table "follows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "followable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "followable_id", null: false
    t.index ["ace_id", "followable_type", "followable_id"], name: "index_follows_on_ace_id_and_followable_type_and_followable_id", unique: true
    t.index ["ace_id"], name: "index_follows_on_ace_id"
    t.index ["followable_type", "followable_id"], name: "index_follows_on_followable"
    t.check_constraint "followable_type::text = ANY (ARRAY['Team'::character varying, 'Player'::character varying]::text[])", name: "follows_supported_type"
  end

  create_table "game_attempts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "game_type", null: false
    t.string "subject_entity_type", null: false
    t.string "target_entity_type", null: false
    t.jsonb "options_presented", default: [], null: false
    t.string "chosen_entity_type"
    t.boolean "is_correct", null: false
    t.integer "time_elapsed_ms", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "difficulty_level"
    t.integer "round_position"
    t.uuid "ace_id", null: false
    t.uuid "game_round_id"
    t.uuid "subject_entity_id", null: false
    t.uuid "target_entity_id", null: false
    t.uuid "chosen_entity_id"
    t.index ["ace_id"], name: "index_game_attempts_on_ace_id"
    t.index ["chosen_entity_type", "chosen_entity_id"], name: "index_game_attempts_on_chosen_entity"
    t.index ["game_round_id", "round_position"], name: "index_game_attempts_on_game_round_id_and_round_position", unique: true
    t.index ["game_round_id"], name: "index_game_attempts_on_game_round_id"
    t.index ["subject_entity_type", "subject_entity_id"], name: "index_game_attempts_on_subject_entity"
    t.index ["target_entity_type", "target_entity_id"], name: "index_game_attempts_on_target_entity"
    t.check_constraint "game_round_id IS NULL AND round_position IS NULL OR game_round_id IS NOT NULL AND round_position >= 0", name: "game_attempt_round_position"
  end

  create_table "game_rounds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "game_type", null: false
    t.integer "length", null: false
    t.jsonb "scope", default: {}, null: false
    t.string "scope_label", null: false
    t.jsonb "questions", default: [], null: false
    t.integer "position", default: 0, null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "paused_at"
    t.datetime "question_started_at"
    t.integer "question_elapsed_ms", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "newly_known_player_ids", default: [], null: false
    t.uuid "ace_id", null: false
    t.index ["ace_id"], name: "index_game_rounds_on_ace_id"
    t.check_constraint "length >= 1 AND length <= 30 AND \"position\" >= 0 AND \"position\" <= length", name: "game_round_progress"
  end

  create_table "goal_achievements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "player_ids", default: [], null: false
    t.jsonb "required_player_ids", default: [], null: false
    t.jsonb "practice_scope", default: {}, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "achievement_id", null: false
    t.uuid "goal_id", null: false
    t.index ["achievement_id"], name: "index_goal_achievements_on_achievement_id"
    t.index ["goal_id", "achievement_id"], name: "index_goal_achievements_on_goal_id_and_achievement_id", unique: true
    t.index ["goal_id"], name: "index_goal_achievements_on_goal_id"
  end

  create_table "goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status"
    t.integer "progress"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "quest_id", null: false
    t.index ["ace_id"], name: "index_goals_on_ace_id"
    t.index ["quest_id"], name: "index_goals_on_quest_id"
  end

  create_table "highlights", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "position"
    t.boolean "required", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "moderation_status", default: "approved", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "achievement_id", null: false
    t.uuid "created_by_id"
    t.uuid "quest_id", null: false
    t.index ["achievement_id"], name: "index_highlights_on_achievement_id"
    t.index ["created_by_id"], name: "index_highlights_on_created_by_id"
    t.index ["moderation_status", "created_at"], name: "index_highlights_on_moderation_status_and_created_at"
    t.index ["quest_id", "achievement_id"], name: "index_highlights_on_quest_id_and_achievement_id", unique: true
    t.index ["quest_id"], name: "index_highlights_on_quest_id"
    t.index ["seed_version"], name: "index_highlights_on_seed_version"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'hidden'::character varying]::text[])", name: "highlights_moderation_status"
  end

  create_table "jersey_number_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "number", null: false
    t.date "start_date"
    t.date "end_date"
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "player_id", null: false
    t.uuid "team_id", null: false
    t.index ["entity_code"], name: "index_jersey_number_assignments_on_entity_code", unique: true
    t.index ["player_id"], name: "index_jersey_number_assignments_on_player_id"
    t.index ["team_id"], name: "index_jersey_number_assignments_on_team_id"
    t.check_constraint "number::text ~ '^[0-9]{1,3}$'::text", name: "jersey_numbers_are_numeric_strings"
    t.check_constraint "start_date IS NULL OR end_date IS NULL OR end_date >= start_date", name: "jersey_numbers_have_ordered_dates"
    t.exclusion_constraint "player_id WITH =, team_id WITH =, daterange(start_date, end_date, '[]'::text) WITH &&", using: :gist, name: "jersey_numbers_do_not_overlap"
  end

  create_table "leagues", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbreviation"
    t.string "url"
    t.string "ios_app_url"
    t.integer "year_of_origin"
    t.string "official_rules_url"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jurisdiction_type"
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "primary_logo_id"
    t.uuid "sport_id", null: false
    t.uuid "jurisdiction_id"
    t.index ["entity_code"], name: "index_leagues_on_entity_code", unique: true
    t.index ["jurisdiction_type", "jurisdiction_id"], name: "index_leagues_on_jurisdiction"
    t.index ["primary_logo_id"], name: "index_leagues_on_primary_logo_id"
    t.index ["seed_version"], name: "index_leagues_on_seed_version"
    t.index ["sport_id"], name: "index_leagues_on_sport_id"
  end

  create_table "logos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "role"
    t.date "start_date"
    t.date "end_date"
    t.boolean "ongoing", default: false, null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "owner_type", null: false
    t.uuid "owner_id", null: false
    t.index ["entity_code"], name: "index_logos_on_entity_code", unique: true
    t.index ["owner_type", "owner_id"], name: "index_logos_on_owner_type_and_owner_id"
    t.check_constraint "NOT ongoing OR end_date IS NULL", name: "logos_ongoing_without_end"
    t.check_constraint "owner_type::text = ANY (ARRAY['Sport'::character varying, 'League'::character varying, 'Conference'::character varying, 'Division'::character varying, 'Team'::character varying]::text[])", name: "logo_owner_type"
    t.check_constraint "start_date IS NULL OR end_date IS NULL OR end_date >= start_date", name: "logos_ordered_dates"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "conference_id"
    t.uuid "division_id"
    t.uuid "league_id", null: false
    t.uuid "team_id", null: false
    t.index ["conference_id"], name: "index_memberships_on_conference_id"
    t.index ["division_id"], name: "index_memberships_on_division_id"
    t.index ["entity_code"], name: "index_memberships_on_entity_code", unique: true
    t.index ["league_id"], name: "index_memberships_on_league_id"
    t.index ["seed_version"], name: "index_memberships_on_seed_version"
    t.index ["team_id"], name: "index_memberships_on_team_id"
  end

  create_table "moderation_decisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subject_type", null: false
    t.string "action", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.integer "revision", null: false
    t.text "reason"
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.uuid "actor_id"
    t.uuid "subject_id", null: false
    t.index ["actor_id"], name: "index_moderation_decisions_on_actor_id"
    t.index ["created_at", "id"], name: "index_moderation_decisions_on_created_at_and_id"
    t.index ["subject_type", "subject_id"], name: "index_moderation_decisions_on_subject"
  end

  create_table "moderation_escalations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subject_type", null: false
    t.string "subject_name", null: false
    t.text "reason", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.integer "revision"
    t.string "captured_status"
    t.string "request_key", limit: 128, null: false
    t.string "resolution"
    t.text "resolution_reason"
    t.datetime "resolved_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "requested_by_id"
    t.uuid "resolved_by_id"
    t.uuid "subject_ace_id"
    t.uuid "subject_id", null: false
    t.index ["requested_by_id", "request_key"], name: "unique_escalation_request", unique: true
    t.index ["requested_by_id"], name: "index_moderation_escalations_on_requested_by_id"
    t.index ["resolved_at", "created_at", "id"], name: "idx_on_resolved_at_created_at_id_b4f1098179"
    t.index ["resolved_by_id"], name: "index_moderation_escalations_on_resolved_by_id"
    t.index ["subject_ace_id"], name: "index_moderation_escalations_on_subject_ace_id"
    t.index ["subject_type", "subject_id"], name: "index_moderation_escalations_on_subject"
    t.index ["subject_type", "subject_id"], name: "one_open_escalation_per_subject", unique: true, where: "(resolved_at IS NULL)"
  end

  create_table "moderator_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.string "request_key", limit: 128, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "moderator_id"
    t.index ["ace_id", "request_key"], name: "index_moderator_notes_on_ace_id_and_request_key", unique: true
    t.index ["ace_id"], name: "index_moderator_notes_on_ace_id"
    t.index ["moderator_id"], name: "index_moderator_notes_on_moderator_id"
  end

  create_table "mutes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "reason", limit: 2000, null: false
    t.text "note"
    t.integer "duration_hours", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "request_key", limit: 128, null: false
    t.datetime "ended_at"
    t.string "end_reason", limit: 2000
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "ended_by_id"
    t.uuid "hidden_shout_out_id"
    t.uuid "moderator_id"
    t.index ["ace_id", "ends_at"], name: "index_mutes_on_ace_id_and_ends_at"
    t.index ["ace_id", "request_key"], name: "index_mutes_on_ace_id_and_request_key", unique: true
    t.index ["ace_id"], name: "index_mutes_on_ace_id"
    t.index ["ended_by_id"], name: "index_mutes_on_ended_by_id"
    t.index ["hidden_shout_out_id"], name: "index_mutes_on_hidden_shout_out_id"
    t.index ["moderator_id"], name: "index_mutes_on_moderator_id"
    t.check_constraint "(duration_hours = ANY (ARRAY[24, 168, 720])) AND ends_at > starts_at", name: "valid_posting_mute_duration"
  end

  create_table "organization_affiliations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.json "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_code"
    t.uuid "organization_id", null: false
    t.uuid "team_id", null: false
    t.index ["entity_code"], name: "index_organization_affiliations_on_entity_code", unique: true
    t.index ["organization_id", "team_id", "start_date"], name: "index_org_affiliations_on_org_team_start", unique: true
    t.index ["organization_id"], name: "index_organization_affiliations_on_organization_id"
    t.index ["team_id"], name: "index_organization_affiliations_on_team_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation"
    t.text "description"
    t.string "url"
    t.string "logo_url"
    t.integer "founded_year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_code"
    t.index ["entity_code"], name: "index_organizations_on_entity_code", unique: true
  end

  create_table "player_group_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "entity_code"
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "player_group_id", null: false
    t.uuid "player_id", null: false
    t.index ["entity_code"], name: "index_player_group_memberships_on_entity_code", unique: true
    t.index ["player_group_id", "player_id"], name: "idx_on_player_group_id_player_id_f1ff3bc069", unique: true
    t.index ["player_group_id"], name: "index_player_group_memberships_on_player_group_id"
    t.index ["player_id"], name: "index_player_group_memberships_on_player_id"
  end

  create_table "player_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "entity_code"
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_code"], name: "index_player_groups_on_entity_code", unique: true
  end

  create_table "players", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "birthdate"
    t.string "current_position"
    t.integer "debut_year"
    t.integer "draft_year"
    t.boolean "active"
    t.text "bio", default: [], array: true
    t.text "photo_urls", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "birth_city_id"
    t.uuid "birth_country_id"
    t.uuid "figure_id", null: false
    t.uuid "sport_id"
    t.uuid "team_id"
    t.index ["birth_city_id"], name: "index_players_on_birth_city_id"
    t.index ["birth_country_id"], name: "index_players_on_birth_country_id"
    t.index ["entity_code"], name: "index_players_on_entity_code", unique: true
    t.index ["figure_id"], name: "index_players_on_figure_id"
    t.index ["seed_version"], name: "index_players_on_seed_version"
    t.index ["sport_id"], name: "index_players_on_sport_id"
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "position_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subject_type", null: false
    t.integer "sequence"
    t.boolean "primary", default: false, null: false
    t.jsonb "statistics", default: {}, null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "position_id", null: false
    t.uuid "subject_id", null: false
    t.index ["entity_code"], name: "index_position_assignments_on_entity_code", unique: true
    t.index ["position_id"], name: "index_position_assignments_on_position_id"
    t.index ["subject_type", "subject_id", "position_id"], name: "index_position_assignments_on_subject_and_unsequenced_position", unique: true, where: "(sequence IS NULL)"
    t.index ["subject_type", "subject_id", "sequence"], name: "index_position_assignments_on_subject_and_sequence", unique: true, where: "(sequence IS NOT NULL)"
    t.index ["subject_type", "subject_id"], name: "index_position_assignments_on_subject"
    t.index ["subject_type", "subject_id"], name: "index_position_assignments_on_subject_primary", unique: true, where: "\"primary\""
    t.check_constraint "sequence IS NULL OR sequence > 0", name: "position_assignments_have_positive_sequences"
    t.check_constraint "subject_type::text = ANY (ARRAY['Player'::character varying, 'RosterEntry'::character varying, 'Appearance'::character varying]::text[])", name: "position_assignments_have_known_subjects"
  end

  create_table "positions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.string "kind", default: "position", null: false
    t.uuid "parent_id"
    t.uuid "sport_id", null: false
    t.index ["entity_code"], name: "index_positions_on_entity_code", unique: true
    t.index ["name", "sport_id"], name: "index_positions_on_name_and_sport_id", unique: true
    t.index ["parent_id"], name: "index_positions_on_parent_id"
    t.index ["seed_version"], name: "index_positions_on_seed_version"
    t.index ["sport_id"], name: "index_positions_on_sport_id"
    t.check_constraint "kind::text = ANY (ARRAY['position'::character varying, 'apparatus'::character varying, 'event'::character varying, 'weapon'::character varying]::text[])", name: "positions_have_known_kinds"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "positions_are_not_their_own_parent"
  end

  create_table "practice_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "figure_practice_relationship_id", null: false
    t.uuid "practice_id", null: false
    t.index ["entity_code"], name: "index_practice_connections_on_entity_code", unique: true
    t.index ["figure_practice_relationship_id", "practice_id"], name: "index_practice_connections_uniquely", unique: true
    t.index ["figure_practice_relationship_id"], name: "index_practice_connections_on_figure_practice_relationship_id"
    t.index ["practice_id"], name: "index_practice_connections_on_practice_id"
  end

  create_table "practice_reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "game_type", null: false
    t.string "subject_type", null: false
    t.string "target_type", null: false
    t.jsonb "question", null: false
    t.integer "correct_streak", default: 0, null: false
    t.datetime "due_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "last_attempt_id", null: false
    t.uuid "subject_id", null: false
    t.uuid "target_id", null: false
    t.index ["ace_id", "due_at"], name: "index_practice_reviews_on_ace_id_and_due_at"
    t.index ["ace_id", "game_type", "subject_type", "subject_id", "target_type", "target_id"], name: "index_practice_reviews_on_identity", unique: true
    t.index ["ace_id"], name: "index_practice_reviews_on_ace_id"
    t.index ["last_attempt_id"], name: "index_practice_reviews_on_last_attempt_id"
  end

  create_table "practices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_code"], name: "index_practices_on_entity_code", unique: true
    t.index ["name"], name: "index_practices_on_name"
  end

  create_table "protocols", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "routine"
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_code"], name: "index_protocols_on_entity_code", unique: true
    t.index ["name"], name: "index_protocols_on_name"
  end

  create_table "quests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.json "details"
    t.string "moderation_status", default: "approved", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "created_by_id"
    t.index ["created_by_id"], name: "index_quests_on_created_by_id"
    t.index ["moderation_status", "created_at"], name: "index_quests_on_moderation_status_and_created_at"
    t.index ["seed_version"], name: "index_quests_on_seed_version"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'hidden'::character varying]::text[])", name: "quests_moderation_status"
  end

  create_table "rating_revisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "rated_type", null: false
    t.bigint "value", null: false
    t.text "notes"
    t.boolean "archived", null: false
    t.jsonb "dimension", null: false
    t.string "operation", null: false
    t.datetime "created_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "rating_id", null: false
    t.uuid "spectrum_id", null: false
    t.uuid "rated_id", null: false
    t.index ["ace_id"], name: "index_rating_revisions_on_ace_id"
    t.index ["rated_type", "rated_id"], name: "index_rating_revisions_on_rated"
    t.index ["rating_id", "id"], name: "index_rating_revisions_on_rating_id_and_id"
    t.check_constraint "operation::text = ANY (ARRAY['set'::character varying, 'archive'::character varying, 'remove'::character varying]::text[])", name: "rating_revisions_valid_operation"
  end

  create_table "ratings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "rated_type", null: false
    t.bigint "value", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "archived", default: false, null: false
    t.uuid "ace_id", null: false
    t.uuid "spectrum_id", null: false
    t.uuid "rated_id", null: false
    t.index ["ace_id", "spectrum_id", "rated_type", "rated_id"], name: "index_ratings_on_ace_spectrum_and_rated_active", unique: true, where: "(archived = false)"
    t.index ["ace_id"], name: "index_ratings_on_ace_id"
    t.index ["archived"], name: "index_ratings_on_archived"
    t.index ["rated_type", "rated_id"], name: "index_ratings_on_rated"
    t.index ["spectrum_id"], name: "index_ratings_on_spectrum_id"
    t.check_constraint "value >= '-100'::integer AND value <= 500", name: "ratings_value_in_standard_scale"
  end

  create_table "rizz_backchannel_logout_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "jti", null: false
    t.string "rizz_sub", null: false
    t.integer "rizz_epoch", null: false
    t.datetime "processed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_rizz_backchannel_logout_events_on_jti", unique: true
    t.index ["rizz_sub"], name: "index_rizz_backchannel_logout_events_on_rizz_sub"
  end

  create_table "rizz_claim_handoffs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "handoff_jti", null: false
    t.string "operation_id", null: false
    t.string "speaker_label", null: false
    t.string "callback_uri", null: false
    t.string "browser_token_digest", null: false
    t.uuid "verified_ace_id"
    t.datetime "verified_at"
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "intent", default: "claim", null: false
    t.string "email"
    t.string "username"
    t.string "display_name"
    t.string "encrypted_password"
    t.index ["handoff_jti"], name: "index_rizz_claim_handoffs_on_handoff_jti", unique: true
    t.index ["operation_id"], name: "index_rizz_claim_handoffs_on_operation_id"
    t.index ["verified_ace_id"], name: "index_rizz_claim_handoffs_on_verified_ace_id"
    t.check_constraint "intent::text = ANY (ARRAY['claim'::character varying, 'create'::character varying]::text[])", name: "rizz_claim_handoffs_intent"
  end

  create_table "rizz_claim_receipts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "receipt_digest", null: false
    t.uuid "ace_id"
    t.string "operation_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "rizz_claim_handoff_id"
    t.index ["ace_id"], name: "index_rizz_claim_receipts_on_ace_id"
    t.index ["operation_id"], name: "index_rizz_claim_receipts_on_operation_id"
    t.index ["receipt_digest"], name: "index_rizz_claim_receipts_on_receipt_digest", unique: true
    t.index ["rizz_claim_handoff_id"], name: "index_rizz_claim_receipts_on_rizz_claim_handoff_id"
    t.check_constraint "ace_id IS NOT NULL OR rizz_claim_handoff_id IS NOT NULL", name: "rizz_claim_receipts_subject"
  end

  create_table "rizz_feed_cursors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "purpose", null: false
    t.string "cursor"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purpose"], name: "index_rizz_feed_cursors_on_purpose", unique: true
  end

  create_table "rizz_names", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "purpose", null: false
    t.string "state", default: "current", null: false
    t.uuid "rizz_entity_id"
    t.string "rizz_code"
    t.string "display_name"
    t.string "sort_key"
    t.jsonb "search_forms", default: [], null: false
    t.uuid "form_id"
    t.uuid "rule_id"
    t.string "view_version"
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "figure_id", null: false
    t.index ["figure_id", "purpose"], name: "index_rizz_names_on_figure_id_and_purpose", unique: true
    t.index ["purpose", "rizz_entity_id"], name: "index_rizz_names_on_purpose_and_rizz_entity_id"
    t.check_constraint "state::text = ANY (ARRAY['current'::character varying, 'invalidated'::character varying]::text[])", name: "rizz_names_state"
  end

  create_table "rizz_syncs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "state", default: "pending", null: false
    t.uuid "rizz_entity_id"
    t.integer "rizz_version"
    t.string "rizz_code"
    t.string "source_revision"
    t.uuid "review_id"
    t.string "last_error"
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "figure_id", null: false
    t.index ["figure_id"], name: "index_rizz_syncs_on_figure_id", unique: true
    t.index ["rizz_entity_id"], name: "index_rizz_syncs_on_rizz_entity_id"
    t.index ["state"], name: "index_rizz_syncs_on_state"
    t.check_constraint "state::text = ANY (ARRAY['pending'::character varying, 'synced'::character varying, 'review'::character varying, 'merge_needed'::character varying, 'failed'::character varying, 'skipped'::character varying]::text[])", name: "rizz_syncs_state"
  end

  create_table "roster_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status"
    t.string "jersey_number"
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "player_id", null: false
    t.uuid "roster_id", null: false
    t.uuid "stint_id"
    t.index ["entity_code"], name: "index_roster_entries_on_entity_code", unique: true
    t.index ["player_id"], name: "index_roster_entries_on_player_id"
    t.index ["roster_id", "player_id"], name: "index_roster_entries_on_roster_id_and_player_id", unique: true
    t.index ["roster_id"], name: "index_roster_entries_on_roster_id"
    t.index ["stint_id"], name: "index_roster_entries_on_stint_id"
  end

  create_table "rosters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", null: false
    t.date "effective_on"
    t.datetime "observed_at"
    t.string "coverage", default: "unknown", null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "campaign_id", null: false
    t.index ["campaign_id", "kind", "effective_on"], name: "index_rosters_on_campaign_id_and_kind_and_effective_on"
    t.index ["campaign_id"], name: "index_rosters_on_campaign_id"
    t.index ["entity_code"], name: "index_rosters_on_entity_code", unique: true
    t.check_constraint "coverage::text = ANY (ARRAY['unknown'::character varying, 'partial'::character varying, 'complete'::character varying]::text[])", name: "rosters_have_known_coverage_labels"
  end

  create_table "seasons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "start_date", comment: "When the regular season started"
    t.date "end_date", comment: "When the regular season ended"
    t.date "playoff_start_date", comment: "When the playoffs started"
    t.date "playoff_end_date", comment: "When the playoffs ended"
    t.text "comments", default: [], comment: "Array of comments about the season", array: true
    t.string "seed_version", comment: "Version when this record was seeded"
    t.datetime "last_seeded_at", comment: "When this record was last seeded"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label"
    t.string "entity_code"
    t.uuid "champion_id"
    t.uuid "championship_contest_id"
    t.uuid "league_id", null: false
    t.uuid "year_id", null: false
    t.index ["champion_id"], name: "index_seasons_on_champion_id"
    t.index ["championship_contest_id"], name: "index_seasons_on_championship_contest_id"
    t.index ["entity_code"], name: "index_seasons_on_entity_code", unique: true
    t.index ["league_id"], name: "index_seasons_on_league_id"
    t.index ["seed_version"], name: "index_seasons_on_seed_version"
    t.index ["start_date"], name: "index_seasons_on_start_date"
    t.index ["year_id", "league_id"], name: "index_seasons_on_year_and_league", unique: true
    t.index ["year_id"], name: "index_seasons_on_year_id"
  end

  create_table "shout_out_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "target_type"
    t.text "message", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "target_id"
    t.index ["ace_id"], name: "index_shout_out_drafts_on_ace_id"
    t.index ["target_type", "target_id"], name: "index_shout_out_drafts_on_target"
    t.check_constraint "target_type IS NULL OR (target_type::text = ANY (ARRAY['Team'::character varying, 'Player'::character varying]::text[]))", name: "drafts_supported_target"
  end

  create_table "shout_out_reactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "shout_out_id", null: false
    t.index ["ace_id"], name: "index_shout_out_reactions_on_ace_id"
    t.index ["shout_out_id", "ace_id", "kind"], name: "index_shout_out_reactions_on_shout_out_id_and_ace_id_and_kind", unique: true
    t.index ["shout_out_id"], name: "index_shout_out_reactions_on_shout_out_id"
    t.check_constraint "kind::text = ANY (ARRAY['fire'::character varying, 'love'::character varying, 'legend'::character varying]::text[])", name: "supported_shout_out_reaction"
  end

  create_table "shout_out_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "reason", null: false
    t.text "note"
    t.string "resolution"
    t.text "decision_reason"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "reporter_id"
    t.uuid "resolved_by_id"
    t.uuid "shout_out_id", null: false
    t.index ["reporter_id"], name: "index_shout_out_reports_on_reporter_id"
    t.index ["resolved_at", "shout_out_id"], name: "index_shout_out_reports_on_resolved_at_and_shout_out_id"
    t.index ["resolved_by_id"], name: "index_shout_out_reports_on_resolved_by_id"
    t.index ["shout_out_id", "reporter_id"], name: "index_shout_out_reports_on_shout_out_id_and_reporter_id", unique: true
    t.index ["shout_out_id"], name: "index_shout_out_reports_on_shout_out_id"
    t.check_constraint "reason::text = ANY (ARRAY['Harassment'::character varying, 'Spam'::character varying, 'Off-topic'::character varying, 'Other'::character varying]::text[])", name: "report_reason"
    t.check_constraint "resolution IS NULL AND resolved_at IS NULL OR resolution IS NOT NULL AND (resolution::text = ANY (ARRAY['kept_live'::character varying, 'hidden'::character varying]::text[])) AND resolved_at IS NOT NULL", name: "report_resolution"
  end

  create_table "shout_outs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "target_type"
    t.integer "draft_revision", null: false
    t.string "target_name", null: false
    t.text "message", null: false
    t.bigint "bid_cents", null: false
    t.string "payment_method", null: false
    t.string "funding_status", default: "unfunded", null: false
    t.string "moderation_status", default: "pending", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "created_by_id", null: false
    t.uuid "league_id"
    t.uuid "shout_out_draft_id"
    t.uuid "team_id"
    t.uuid "target_id"
    t.index ["created_by_id"], name: "index_shout_outs_on_created_by_id"
    t.index ["league_id"], name: "index_shout_outs_on_league_id"
    t.index ["shout_out_draft_id", "draft_revision"], name: "index_shout_outs_on_shout_out_draft_id_and_draft_revision", unique: true
    t.index ["shout_out_draft_id"], name: "index_shout_outs_on_shout_out_draft_id"
    t.index ["target_type", "target_id"], name: "index_shout_outs_on_target"
    t.index ["team_id"], name: "index_shout_outs_on_team_id"
    t.check_constraint "(payment_method::text = ANY (ARRAY['credit'::character varying, 'stripe'::character varying]::text[])) AND (funding_status::text = ANY (ARRAY['unfunded'::character varying, 'reserved'::character varying, 'spent'::character varying, 'refunded'::character varying]::text[]))", name: "shout_out_funding_states"
    t.check_constraint "bid_cents > 0", name: "positive_shout_out_bid"
  end

  create_table "sign_in_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "outcome", null: false
    t.string "ip_address", limit: 64
    t.string "user_agent", limit: 512
    t.datetime "created_at", null: false
    t.uuid "ace_id", null: false
    t.index ["ace_id", "created_at", "id"], name: "index_sign_in_events_on_ace_id_and_created_at_and_id"
    t.index ["ace_id"], name: "index_sign_in_events_on_ace_id"
  end

  create_table "spectrums", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "low_label", default: "Low"
    t.string "high_label", default: "High"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "moderation_status", default: "approved", null: false
    t.integer "moderation_revision", default: 1, null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "created_by_id"
    t.index ["created_by_id"], name: "index_spectrums_on_created_by_id"
    t.index ["moderation_status", "created_at"], name: "index_spectrums_on_moderation_status_and_created_at"
    t.index ["name"], name: "index_spectrums_on_name", unique: true
    t.index ["seed_version"], name: "index_spectrums_on_seed_version"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'hidden'::character varying]::text[])", name: "spectrums_moderation_status"
  end

  create_table "sports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon_url"
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "primary_logo_id"
    t.index ["entity_code"], name: "index_sports_on_entity_code", unique: true
    t.index ["primary_logo_id"], name: "index_sports_on_primary_logo_id"
    t.index ["seed_version"], name: "index_sports_on_seed_version"
  end

  create_table "stadiums", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.integer "capacity"
    t.integer "opened_year"
    t.string "url"
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "logo_url"
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "city_id", null: false
    t.index ["city_id"], name: "index_stadiums_on_city_id"
    t.index ["entity_code"], name: "index_stadiums_on_entity_code", unique: true
    t.index ["seed_version"], name: "index_stadiums_on_seed_version"
  end

  create_table "staff_tenures", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "role", null: false
    t.string "title", null: false
    t.string "start_date"
    t.string "end_date"
    t.boolean "ongoing", default: false, null: false
    t.string "entity_code", null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "figure_id", null: false
    t.uuid "organization_id", null: false
    t.uuid "team_id"
    t.index ["entity_code"], name: "index_staff_tenures_on_entity_code", unique: true
    t.index ["figure_id"], name: "index_staff_tenures_on_figure_id"
    t.index ["organization_id"], name: "index_staff_tenures_on_organization_id"
    t.index ["team_id"], name: "index_staff_tenures_on_team_id"
    t.check_constraint "NOT ongoing OR end_date IS NULL", name: "staff_tenures_ongoing_end"
    t.check_constraint "role::text = ANY (ARRAY['coach'::character varying, 'staff'::character varying, 'broadcaster'::character varying]::text[])", name: "staff_tenures_role"
  end

  create_table "states", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbreviation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "flag_url"
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.uuid "country_id", null: false
    t.index ["country_id"], name: "index_states_on_country_id"
    t.index ["entity_code"], name: "index_states_on_entity_code", unique: true
    t.index ["seed_version"], name: "index_states_on_seed_version"
  end

  create_table "stints", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.string "status"
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "contract_id"
    t.uuid "end_transaction_id"
    t.uuid "player_id", null: false
    t.uuid "start_transaction_id"
    t.uuid "team_id", null: false
    t.index ["contract_id"], name: "index_stints_on_contract_id"
    t.index ["end_transaction_id"], name: "index_stints_on_end_transaction_id"
    t.index ["entity_code"], name: "index_stints_on_entity_code", unique: true
    t.index ["player_id", "start_date", "end_date"], name: "index_stints_on_player_id_and_start_date_and_end_date"
    t.index ["player_id"], name: "index_stints_on_player_id"
    t.index ["start_transaction_id"], name: "index_stints_on_start_transaction_id"
    t.index ["team_id", "start_date", "end_date"], name: "index_stints_on_team_id_and_start_date_and_end_date"
    t.index ["team_id"], name: "index_stints_on_team_id"
    t.check_constraint "start_date IS NULL OR end_date IS NULL OR end_date >= start_date", name: "stints_have_ordered_dates"
  end

  create_table "stripe_purchases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.string "request_key", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_session_id"
    t.string "stripe_payment_intent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "shout_out_id"
    t.index ["ace_id", "request_key"], name: "index_stripe_purchases_on_ace_id_and_request_key", unique: true
    t.index ["ace_id"], name: "index_stripe_purchases_on_ace_id"
    t.index ["shout_out_id"], name: "index_stripe_purchases_on_shout_out_id"
    t.index ["stripe_payment_intent_id"], name: "index_stripe_purchases_on_stripe_payment_intent_id", unique: true
    t.index ["stripe_session_id"], name: "index_stripe_purchases_on_stripe_session_id", unique: true
    t.check_constraint "amount_cents >= 50 AND amount_cents <= 99999999 AND (status::text = ANY (ARRAY['pending'::character varying, 'paid'::character varying, 'expired'::character varying]::text[]))", name: "stripe_purchase_amount_and_status"
  end

  create_table "teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "mascot"
    t.string "territory"
    t.integer "founded_year"
    t.string "abbreviation"
    t.string "url"
    t.string "logo_url"
    t.string "primary_color"
    t.string "secondary_color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.string "entity_code"
    t.string "text_color"
    t.uuid "league_id", null: false
    t.uuid "primary_logo_id"
    t.uuid "stadium_id"
    t.index ["entity_code"], name: "index_teams_on_entity_code", unique: true
    t.index ["league_id"], name: "index_teams_on_league_id"
    t.index ["primary_logo_id"], name: "index_teams_on_primary_logo_id"
    t.index ["seed_version"], name: "index_teams_on_seed_version"
    t.index ["stadium_id"], name: "index_teams_on_stadium_id"
  end

  create_table "title_awards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.date "awarded_on"
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "contest_id", null: false
    t.uuid "player_id"
    t.uuid "winner_id"
    t.index ["contest_id", "key"], name: "index_title_awards_on_contest_id_and_key", unique: true
    t.index ["contest_id"], name: "index_title_awards_on_contest_id"
    t.index ["entity_code"], name: "index_title_awards_on_entity_code", unique: true
    t.index ["player_id"], name: "index_title_awards_on_player_id"
    t.check_constraint "winner_id IS NOT NULL OR player_id IS NOT NULL", name: "title_awards_have_a_recipient"
  end

  create_table "topics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "entity_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_code"], name: "index_topics_on_entity_code", unique: true
    t.index ["name"], name: "index_topics_on_name", unique: true
  end

  create_table "transaction_players", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "from_organization_id"
    t.uuid "from_team_id"
    t.uuid "player_id", null: false
    t.uuid "to_organization_id"
    t.uuid "to_team_id"
    t.uuid "transaction_id", null: false
    t.index ["entity_code"], name: "index_transaction_players_on_entity_code", unique: true
    t.index ["from_organization_id"], name: "index_transaction_players_on_from_organization_id"
    t.index ["from_team_id"], name: "index_transaction_players_on_from_team_id"
    t.index ["player_id"], name: "index_transaction_players_on_player_id"
    t.index ["to_organization_id"], name: "index_transaction_players_on_to_organization_id"
    t.index ["to_team_id"], name: "index_transaction_players_on_to_team_id"
    t.index ["transaction_id", "player_id"], name: "index_transaction_players_on_transaction_id_and_player_id", unique: true
    t.index ["transaction_id"], name: "index_transaction_players_on_transaction_id"
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", null: false
    t.date "effective_on"
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["effective_on", "kind"], name: "index_transactions_on_effective_on_and_kind"
    t.index ["entity_code"], name: "index_transactions_on_entity_code", unique: true
  end

  create_table "uniform_campaigns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "campaign_id", null: false
    t.uuid "uniform_id", null: false
    t.index ["campaign_id"], name: "index_uniform_campaigns_on_campaign_id"
    t.index ["entity_code"], name: "index_uniform_campaigns_on_entity_code", unique: true
    t.index ["uniform_id", "campaign_id"], name: "index_uniform_campaigns_on_uniform_id_and_campaign_id", unique: true
    t.index ["uniform_id"], name: "index_uniform_campaigns_on_uniform_id"
  end

  create_table "uniform_pieces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uniform_id", null: false
    t.index ["entity_code"], name: "index_uniform_pieces_on_entity_code", unique: true
    t.index ["uniform_id", "name"], name: "index_uniform_pieces_on_uniform_id_and_name", unique: true
    t.index ["uniform_id"], name: "index_uniform_pieces_on_uniform_id"
  end

  create_table "uniforms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "role"
    t.date "start_date"
    t.date "end_date"
    t.boolean "ongoing", default: false, null: false
    t.jsonb "source", default: {}, null: false
    t.jsonb "details", default: {}, null: false
    t.string "entity_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "team_id", null: false
    t.index ["entity_code"], name: "index_uniforms_on_entity_code", unique: true
    t.index ["team_id"], name: "index_uniforms_on_team_id"
    t.check_constraint "NOT ongoing OR end_date IS NULL", name: "uniforms_ongoing_without_end"
    t.check_constraint "start_date IS NULL OR end_date IS NULL OR end_date >= start_date", name: "uniforms_ordered_dates"
  end

  create_table "warnings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "reason", limit: 2000, null: false
    t.string "subject_type"
    t.string "subject_name"
    t.string "request_key", limit: 128, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "ace_id", null: false
    t.uuid "moderator_id"
    t.uuid "subject_id"
    t.index ["ace_id", "request_key"], name: "index_warnings_on_ace_id_and_request_key", unique: true
    t.index ["ace_id"], name: "index_warnings_on_ace_id"
    t.index ["moderator_id"], name: "index_warnings_on_moderator_id"
    t.index ["subject_type", "subject_id"], name: "index_warnings_on_subject"
  end

  create_table "years", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "number", null: false, comment: "The year number (e.g., 2024)"
    t.string "seed_version", comment: "Version of the seed file that created or last updated this record"
    t.datetime "last_seeded_at", comment: "When this record was last updated by a seed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_code"
    t.index ["entity_code"], name: "index_years_on_entity_code", unique: true
    t.index ["number"], name: "index_years_on_number", unique: true
    t.index ["seed_version"], name: "index_years_on_seed_version"
  end

  add_foreign_key "account_actions", "aces", column: "actor_id", on_delete: :nullify
  add_foreign_key "account_actions", "aces", on_delete: :nullify
  add_foreign_key "ace_rizz_bindings", "aces", on_delete: :cascade
  add_foreign_key "achievements", "aces", column: "created_by_id", on_delete: :nullify
  add_foreign_key "activations", "campaigns"
  add_foreign_key "activations", "contracts"
  add_foreign_key "activations", "players"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appearances", "contestants"
  add_foreign_key "appearances", "players"
  add_foreign_key "appearances", "stints"
  add_foreign_key "attestations", "aces", column: "entered_by_id"
  add_foreign_key "attestations", "figures", column: "author_id"
  add_foreign_key "attributed_statements", "figure_practice_relationships"
  add_foreign_key "attributed_statements", "figures"
  add_foreign_key "attributed_statements", "figures", column: "observer_id"
  add_foreign_key "attributed_statements", "staff_tenures"
  add_foreign_key "attributed_statements", "topics"
  add_foreign_key "campaigns", "cities"
  add_foreign_key "campaigns", "conferences"
  add_foreign_key "campaigns", "divisions"
  add_foreign_key "campaigns", "seasons"
  add_foreign_key "campaigns", "stadiums"
  add_foreign_key "campaigns", "teams"
  add_foreign_key "catalog_edits", "aces", column: "actor_id", on_delete: :nullify
  add_foreign_key "cities", "states"
  add_foreign_key "conferences", "leagues"
  add_foreign_key "conferences", "logos", column: "primary_logo_id", on_delete: :nullify
  add_foreign_key "contest_games", "contests"
  add_foreign_key "contest_games", "contests", column: "game_id"
  add_foreign_key "contestants", "campaigns"
  add_foreign_key "contestants", "contests"
  add_foreign_key "contests", "seasons"
  add_foreign_key "contests", "stadiums"
  add_foreign_key "contests", "teams", column: "champion_id", on_delete: :nullify
  add_foreign_key "contracts", "organizations"
  add_foreign_key "contracts", "players"
  add_foreign_key "contracts", "teams"
  add_foreign_key "credit_accounts", "aces"
  add_foreign_key "credit_entries", "credit_accounts"
  add_foreign_key "divisions", "conferences"
  add_foreign_key "divisions", "leagues"
  add_foreign_key "divisions", "logos", column: "primary_logo_id", on_delete: :nullify
  add_foreign_key "figure_business_relationships", "businesses"
  add_foreign_key "figure_business_relationships", "figures"
  add_foreign_key "figure_practice_relationships", "figures"
  add_foreign_key "figure_practice_relationships", "protocols"
  add_foreign_key "figures", "asset_representations", column: "primary_portrait_id", on_delete: :nullify
  add_foreign_key "follows", "aces"
  add_foreign_key "game_attempts", "aces"
  add_foreign_key "game_attempts", "game_rounds"
  add_foreign_key "game_rounds", "aces"
  add_foreign_key "goal_achievements", "achievements"
  add_foreign_key "goal_achievements", "goals"
  add_foreign_key "goals", "aces"
  add_foreign_key "goals", "quests"
  add_foreign_key "highlights", "aces", column: "created_by_id", on_delete: :nullify
  add_foreign_key "highlights", "achievements"
  add_foreign_key "highlights", "quests"
  add_foreign_key "jersey_number_assignments", "players"
  add_foreign_key "jersey_number_assignments", "teams"
  add_foreign_key "leagues", "logos", column: "primary_logo_id", on_delete: :nullify
  add_foreign_key "leagues", "sports"
  add_foreign_key "memberships", "conferences"
  add_foreign_key "memberships", "divisions"
  add_foreign_key "memberships", "leagues"
  add_foreign_key "memberships", "teams"
  add_foreign_key "moderation_decisions", "aces", column: "actor_id", on_delete: :nullify
  add_foreign_key "moderation_escalations", "aces", column: "requested_by_id", on_delete: :nullify
  add_foreign_key "moderation_escalations", "aces", column: "resolved_by_id", on_delete: :nullify
  add_foreign_key "moderation_escalations", "aces", column: "subject_ace_id", on_delete: :nullify
  add_foreign_key "moderator_notes", "aces", column: "moderator_id", on_delete: :nullify
  add_foreign_key "moderator_notes", "aces", on_delete: :cascade
  add_foreign_key "mutes", "aces", column: "ended_by_id", on_delete: :nullify
  add_foreign_key "mutes", "aces", column: "moderator_id", on_delete: :nullify
  add_foreign_key "mutes", "aces", on_delete: :cascade
  add_foreign_key "mutes", "shout_outs", column: "hidden_shout_out_id"
  add_foreign_key "organization_affiliations", "organizations"
  add_foreign_key "organization_affiliations", "teams"
  add_foreign_key "player_group_memberships", "player_groups"
  add_foreign_key "player_group_memberships", "players"
  add_foreign_key "players", "cities", column: "birth_city_id"
  add_foreign_key "players", "countries", column: "birth_country_id"
  add_foreign_key "players", "figures"
  add_foreign_key "players", "sports"
  add_foreign_key "players", "teams"
  add_foreign_key "position_assignments", "positions"
  add_foreign_key "positions", "positions", column: "parent_id"
  add_foreign_key "positions", "sports"
  add_foreign_key "practice_connections", "figure_practice_relationships", on_delete: :cascade
  add_foreign_key "practice_connections", "practices"
  add_foreign_key "practice_reviews", "aces"
  add_foreign_key "practice_reviews", "game_attempts", column: "last_attempt_id", on_delete: :cascade
  add_foreign_key "quests", "aces", column: "created_by_id", on_delete: :nullify
  add_foreign_key "rating_revisions", "aces"
  add_foreign_key "ratings", "aces"
  add_foreign_key "ratings", "spectrums"
  add_foreign_key "rizz_claim_handoffs", "aces", column: "verified_ace_id", on_delete: :nullify
  add_foreign_key "rizz_claim_receipts", "aces", on_delete: :cascade
  add_foreign_key "rizz_claim_receipts", "rizz_claim_handoffs", on_delete: :cascade
  add_foreign_key "rizz_names", "figures", on_delete: :cascade
  add_foreign_key "rizz_syncs", "figures"
  add_foreign_key "roster_entries", "players"
  add_foreign_key "roster_entries", "rosters"
  add_foreign_key "roster_entries", "stints"
  add_foreign_key "rosters", "campaigns"
  add_foreign_key "seasons", "contests", column: "championship_contest_id"
  add_foreign_key "seasons", "leagues"
  add_foreign_key "seasons", "teams", column: "champion_id"
  add_foreign_key "seasons", "years"
  add_foreign_key "shout_out_drafts", "aces"
  add_foreign_key "shout_out_reactions", "aces", on_delete: :cascade
  add_foreign_key "shout_out_reactions", "shout_outs"
  add_foreign_key "shout_out_reports", "aces", column: "reporter_id", on_delete: :nullify
  add_foreign_key "shout_out_reports", "aces", column: "resolved_by_id", on_delete: :nullify
  add_foreign_key "shout_out_reports", "shout_outs"
  add_foreign_key "shout_outs", "aces", column: "created_by_id"
  add_foreign_key "shout_outs", "leagues", on_delete: :nullify
  add_foreign_key "shout_outs", "shout_out_drafts", on_delete: :nullify
  add_foreign_key "shout_outs", "teams", on_delete: :nullify
  add_foreign_key "sign_in_events", "aces", on_delete: :cascade
  add_foreign_key "spectrums", "aces", column: "created_by_id", on_delete: :nullify
  add_foreign_key "sports", "logos", column: "primary_logo_id", on_delete: :nullify
  add_foreign_key "stadiums", "cities"
  add_foreign_key "staff_tenures", "figures"
  add_foreign_key "staff_tenures", "organizations"
  add_foreign_key "staff_tenures", "teams"
  add_foreign_key "states", "countries"
  add_foreign_key "stints", "contracts"
  add_foreign_key "stints", "players"
  add_foreign_key "stints", "teams"
  add_foreign_key "stints", "transactions", column: "end_transaction_id"
  add_foreign_key "stints", "transactions", column: "start_transaction_id"
  add_foreign_key "stripe_purchases", "aces"
  add_foreign_key "stripe_purchases", "shout_outs"
  add_foreign_key "teams", "leagues"
  add_foreign_key "teams", "logos", column: "primary_logo_id", on_delete: :nullify
  add_foreign_key "teams", "stadiums"
  add_foreign_key "title_awards", "contestants", column: ["contest_id", "winner_id"], primary_key: ["contest_id", "id"]
  add_foreign_key "title_awards", "contests"
  add_foreign_key "title_awards", "players"
  add_foreign_key "transaction_players", "organizations", column: "from_organization_id"
  add_foreign_key "transaction_players", "organizations", column: "to_organization_id"
  add_foreign_key "transaction_players", "players"
  add_foreign_key "transaction_players", "teams", column: "from_team_id"
  add_foreign_key "transaction_players", "teams", column: "to_team_id"
  add_foreign_key "transaction_players", "transactions"
  add_foreign_key "uniform_campaigns", "campaigns"
  add_foreign_key "uniform_campaigns", "uniforms"
  add_foreign_key "uniform_pieces", "uniforms"
  add_foreign_key "uniforms", "teams"
  add_foreign_key "warnings", "aces", column: "moderator_id", on_delete: :nullify
  add_foreign_key "warnings", "aces", on_delete: :cascade
end
