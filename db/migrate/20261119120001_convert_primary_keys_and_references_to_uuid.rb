require "json"

class ConvertPrimaryKeysAndReferencesToUuid < ActiveRecord::Migration[8.1]
  EXCLUDED_TABLES = %w[
    schema_migrations
    ar_internal_metadata
  ].freeze

  # Non-FK history columns that reference tables whose rows may be hard-deleted.
  EXPLICIT_NON_FK_REFERENCES = [
    [ "rating_revisions", "rating_id", "ratings" ],
    [ "rating_revisions", "spectrum_id", "spectrums" ]
  ].freeze

  # All 25 polymorphic (table, id_column, type_column) triples in AthleteAce.
  POLYMORPHIC_COLUMNS = [
    [ "achievements", "target_id", "target_type" ],
    [ "active_storage_attachments", "record_id", "record_type" ],
    [ "asset_representations", "subject_id", "subject_type" ],
    [ "attestations", "claim_id", "claim_type" ],
    [ "catalog_edits", "record_id", "record_type" ],
    [ "contests", "context_id", "context_type" ],
    [ "credit_entries", "source_id", "source_type" ],
    [ "decision_evaluations", "subject_id", "subject_type" ],
    [ "entity_codes", "record_id", "record_type" ],
    [ "follows", "followable_id", "followable_type" ],
    [ "game_attempts", "subject_entity_id", "subject_entity_type" ],
    [ "game_attempts", "target_entity_id", "target_entity_type" ],
    [ "game_attempts", "chosen_entity_id", "chosen_entity_type" ],
    [ "leagues", "jurisdiction_id", "jurisdiction_type" ],
    [ "logos", "owner_id", "owner_type" ],
    [ "moderation_decisions", "subject_id", "subject_type" ],
    [ "moderation_escalations", "subject_id", "subject_type" ],
    [ "position_assignments", "subject_id", "subject_type" ],
    [ "practice_reviews", "subject_id", "subject_type" ],
    [ "practice_reviews", "target_id", "target_type" ],
    [ "rating_revisions", "rated_id", "rated_type" ],
    [ "ratings", "rated_id", "rated_type" ],
    [ "shout_out_drafts", "target_id", "target_type" ],
    [ "shout_outs", "target_id", "target_type" ],
    [ "warnings", "subject_id", "subject_type" ]
  ].freeze

  # Explicit model-to-table overrides for STI subclasses and custom table names.
  POLYMORPHIC_TABLE_OVERRIDES = {
    "Game" => "contests",
    "PostingWarning" => "warnings"
  }.freeze

  # Tables that store historical/audit polymorphic references where targets may have been deleted.
  ORPHAN_TOLERANT_TABLES = %w[
    catalog_edits
    credit_entries
    decision_evaluations
    entity_codes
    moderation_decisions
    moderation_escalations
    rating_revisions
    warnings
  ].freeze

  SCOPE_SINGLE_ID_TABLES = {
    "sport_id" => "sports",
    "league_id" => "leagues",
    "season_id" => "seasons",
    "conference_id" => "conferences",
    "division_id" => "divisions",
    "city_id" => "cities",
    "state_id" => "states",
    "team_id" => "teams",
    "goal_achievement_id" => "goal_achievements",
    "player_group_id" => "player_groups",
    "player_id" => "players"
  }.freeze

  SCOPE_ARRAY_ID_TABLES = {
    "team_ids" => "teams",
    "player_ids" => "players"
  }.freeze

  def up
    target_tables = discover_integer_pk_tables
    return if target_tables.empty?

    create_uuid_v7_helper_function

    pk_constraints = capture_primary_keys(target_tables)
    foreign_keys, fk_column_mappings = capture_foreign_keys(target_tables)
    ref_columns_by_table = build_reference_column_map(target_tables, fk_column_mappings)
    column_nullability = capture_column_nullability(target_tables, ref_columns_by_table)

    constraints_to_recreate = capture_check_and_exclusion_constraints(target_tables)
    indexes_to_recreate = capture_affected_indexes(target_tables, ref_columns_by_table)

    say_with_time "Backfilling deterministic UUIDv7 primary keys for #{target_tables.size} tables" do
      target_tables.each do |table|
        ts_expr = timestamp_expression_for(table)
        execute "ALTER TABLE #{qt(table)} ADD COLUMN __uuid_pk uuid"
        execute <<~SQL
          UPDATE #{qt(table)}
          SET __uuid_pk = pg_temp._aa_uuid_v7_from(#{ts_expr}, #{quote(table)}, id)
        SQL
      end
    end

    say_with_time "Backfilling #{fk_column_mappings.size} foreign-key reference columns" do
      fk_column_mappings.each do |mapping|
        add_temp_uuid_col(mapping[:table], mapping[:column])
        execute <<~SQL
          UPDATE #{qt(mapping[:table])} AS child
          SET #{qc(temp_col(mapping[:column]))} = parent.__uuid_pk
          FROM #{qt(mapping[:ref_table])} AS parent
          WHERE child.#{qc(mapping[:column])} = parent.id
        SQL
        verify_no_unmapped!(mapping[:table], mapping[:column])
      end
    end

    say_with_time "Backfilling non-FK history reference columns" do
      EXPLICIT_NON_FK_REFERENCES.each do |table, column, ref_table|
        next unless target_tables.include?(table) && column_exists?(table, column)

        add_temp_uuid_col(table, column)
        execute <<~SQL
          UPDATE #{qt(table)} AS child
          SET #{qc(temp_col(column))} = parent.__uuid_pk
          FROM #{qt(ref_table)} AS parent
          WHERE child.#{qc(column)} = parent.id
        SQL

        # Preserve deterministic grouping for deleted ratings/spectrums in rating_revisions.
        execute <<~SQL
          UPDATE #{qt(table)} AS child
          SET #{qc(temp_col(column))} = orphans.synthetic_uuid
          FROM (
            SELECT #{qc(column)} AS old_id,
                   pg_temp._aa_uuid_v7_from(MIN(created_at), #{quote(ref_table)}, #{qc(column)}) AS synthetic_uuid
            FROM #{qt(table)}
            WHERE #{qc(column)} IS NOT NULL AND #{qc(temp_col(column))} IS NULL
            GROUP BY #{qc(column)}
          ) AS orphans
          WHERE child.#{qc(column)} = orphans.old_id
            AND child.#{qc(temp_col(column))} IS NULL
        SQL
        verify_no_unmapped!(table, column)
      end
    end

    say_with_time "Backfilling #{POLYMORPHIC_COLUMNS.size} polymorphic reference columns" do
      POLYMORPHIC_COLUMNS.each do |table, id_col, type_col|
        next unless target_tables.include?(table) && column_exists?(table, id_col)

        add_temp_uuid_col(table, id_col)
        distinct_types = select_values(<<~SQL)
          SELECT DISTINCT #{qc(type_col)}
          FROM #{qt(table)}
          WHERE #{qc(id_col)} IS NOT NULL AND #{qc(type_col)} IS NOT NULL
        SQL

        distinct_types.each do |type_name|
          parent_table = resolve_polymorphic_table!(type_name, target_tables)
          execute <<~SQL
            UPDATE #{qt(table)} AS child
            SET #{qc(temp_col(id_col))} = parent.__uuid_pk
            FROM #{qt(parent_table)} AS parent
            WHERE child.#{qc(type_col)} = #{quote(type_name)}
              AND child.#{qc(id_col)} = parent.id
          SQL
        end

        unmapped_count = select_value(<<~SQL).to_i
          SELECT COUNT(*) FROM #{qt(table)}
          WHERE #{qc(id_col)} IS NOT NULL AND #{qc(temp_col(id_col))} IS NULL
        SQL

        if unmapped_count.positive?
          if ORPHAN_TOLERANT_TABLES.include?(table)
            say "  NOTE: #{table}.#{id_col} has #{unmapped_count} orphaned historical reference(s); assigning deterministic UUIDv7s", true
            ts_expr = timestamp_expression_for(table, alias_prefix: "child.")
            execute <<~SQL
              UPDATE #{qt(table)} AS child
              SET #{qc(temp_col(id_col))} = pg_temp._aa_uuid_v7_from(
                #{ts_expr},
                COALESCE(child.#{qc(type_col)}, #{quote(table)}),
                child.#{qc(id_col)}
              )
              WHERE child.#{qc(id_col)} IS NOT NULL AND child.#{qc(temp_col(id_col))} IS NULL
            SQL
          else
            raise "Unmapped polymorphic references in #{table}.#{id_col}: #{unmapped_count} rows"
          end
        end
      end
    end

    say_with_time "Remapping live JSONB IDs (game_rounds, practice_reviews, goal_achievements, game_attempts)" do
      remap_live_jsonb_columns(target_tables)
    end

    say_with_time "Dropping foreign keys, check/exclusion constraints, and affected indexes" do
      foreign_keys.each do |fk|
        execute "ALTER TABLE #{qt(fk[:table])} DROP CONSTRAINT #{qc(fk[:name])}"
      end

      constraints_to_recreate.each do |con|
        execute "ALTER TABLE #{qt(con[:table])} DROP CONSTRAINT #{qc(con[:name])}"
      end

      indexes_to_recreate.each do |idx|
        execute "DROP INDEX #{qc(idx[:schema])}.#{qc(idx[:name])}"
      end
    end

    say_with_time "Swapping primary keys and reference columns to uuid" do
      target_tables.each do |table|
        pk_name = pk_constraints.fetch(table)
        execute "ALTER TABLE #{qt(table)} DROP CONSTRAINT #{qc(pk_name)}"
        execute "ALTER TABLE #{qt(table)} DROP COLUMN id"
        execute "ALTER TABLE #{qt(table)} RENAME COLUMN __uuid_pk TO id"
        execute "ALTER TABLE #{qt(table)} ALTER COLUMN id SET NOT NULL"
        execute "ALTER TABLE #{qt(table)} ALTER COLUMN id SET DEFAULT gen_random_uuid()"
        execute "ALTER TABLE #{qt(table)} ADD CONSTRAINT #{qc(pk_name)} PRIMARY KEY (id)"

        ref_columns_by_table.fetch(table, []).each do |col|
          not_null = column_nullability.fetch([ table, col ])
          execute "ALTER TABLE #{qt(table)} DROP COLUMN #{qc(col)}"
          execute "ALTER TABLE #{qt(table)} RENAME COLUMN #{qc(temp_col(col))} TO #{qc(col)}"
          execute "ALTER TABLE #{qt(table)} ALTER COLUMN #{qc(col)} SET NOT NULL" if not_null
        end
      end
    end

    say_with_time "Restoring indexes, check/exclusion constraints, and foreign keys" do
      indexes_to_recreate.each do |idx|
        execute idx[:definition]
      end

      constraints_to_recreate.each do |con|
        execute "ALTER TABLE #{qt(con[:table])} ADD CONSTRAINT #{qc(con[:name])} #{con[:definition]}"
      end

      foreign_keys.each do |fk|
        execute "ALTER TABLE #{qt(fk[:table])} ADD CONSTRAINT #{qc(fk[:name])} #{fk[:definition]}"
      end
    end

    verify_no_remaining_integer_ids!(target_tables)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "UUIDv7 primary key conversion is one-way; restore from backup to revert."
  end

  private

  def qt(table)
    connection.quote_table_name(table)
  end

  def qc(col)
    connection.quote_column_name(col)
  end

  def temp_col(col)
    "__uuid_#{col}"
  end

  def add_temp_uuid_col(table, col)
    return if column_exists?(table, temp_col(col))

    execute "ALTER TABLE #{qt(table)} ADD COLUMN #{qc(temp_col(col))} uuid"
  end

  def create_uuid_v7_helper_function
    # Portable RFC 9562 UUIDv7 generator (PostgreSQL 14–18, zero extension dependencies).
    # Encodes 48-bit Unix ms timestamp, version 7, 12-bit monotonic sub-ms sequence from
    # old_id, RFC 9562 variant 10xx, and 62 deterministic bits from md5(table:old_id).
    execute <<~SQL
      CREATE OR REPLACE FUNCTION pg_temp._aa_uuid_v7_from(ts timestamptz, tbl text, old_id bigint)
      RETURNS uuid LANGUAGE plpgsql IMMUTABLE AS $$
      DECLARE
        ms bigint;
        ms_hex text;
        hash_hex text;
        ver_hi text;
        var_byte int;
        var_hi text;
      BEGIN
        ms := GREATEST(0, floor(extract(epoch FROM COALESCE(ts, TIMESTAMPTZ '2025-01-01 00:00:00+00')) * 1000)::bigint);
        ms_hex := lpad(to_hex(ms), 12, '0');
        hash_hex := md5(tbl || ':' || old_id::text);
        ver_hi := '7' || lpad(to_hex((old_id & 4095)::int), 3, '0');
        var_byte := (get_byte(decode(substr(hash_hex, 1, 2), 'hex'), 0) & 63) | 128;
        var_hi := lpad(to_hex(var_byte), 2, '0');
        RETURN (
          substr(ms_hex, 1, 8) || '-' ||
          substr(ms_hex, 9, 4) || '-' ||
          ver_hi || '-' ||
          var_hi || substr(hash_hex, 3, 2) || '-' ||
          substr(hash_hex, 5, 12)
        )::uuid;
      END;
      $$;
    SQL
  end

  def discover_integer_pk_tables
    rows = select_values(<<~SQL)
      SELECT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_index i ON i.indrelid = c.oid AND i.indisprimary
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(i.indkey)
      WHERE n.nspname = 'public'
        AND c.relkind = 'r'
        AND array_length(i.indkey, 1) = 1
        AND a.attname = 'id'
        AND a.atttypid IN ('int2'::regtype, 'int4'::regtype, 'int8'::regtype)
      ORDER BY c.relname
    SQL
    rows.reject { |t| EXCLUDED_TABLES.include?(t) || t.start_with?("solid_") }
  end

  def timestamp_expression_for(table, alias_prefix: "")
    cols = connection.columns(table).map(&:name)
    col = %w[created_at started_at awarded_on observed_on].find { |candidate| cols.include?(candidate) }
    col ? "#{alias_prefix}#{qc(col)}::timestamptz" : "TIMESTAMPTZ '2025-01-01 00:00:00+00'"
  end

  def capture_primary_keys(target_tables)
    quoted = target_tables.map { |t| quote(t) }.join(", ")
    rows = select_rows(<<~SQL)
      SELECT t.relname, con.conname
      FROM pg_constraint con
      JOIN pg_class t ON t.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'public'
        AND con.contype = 'p'
        AND t.relname IN (#{quoted})
    SQL
    rows.to_h
  end

  def capture_foreign_keys(target_tables)
    quoted = target_tables.map { |t| quote(t) }.join(", ")
    fk_rows = select_rows(<<~SQL)
      SELECT
        con.conname,
        src.relname AS src_table,
        pg_get_constraintdef(con.oid) AS definition
      FROM pg_constraint con
      JOIN pg_class src ON src.oid = con.conrelid
      JOIN pg_namespace src_ns ON src_ns.oid = src.relnamespace
      JOIN pg_class dst ON dst.oid = con.confrelid
      WHERE con.contype = 'f'
        AND src_ns.nspname = 'public'
        AND (src.relname IN (#{quoted}) OR dst.relname IN (#{quoted}))
      ORDER BY src.relname, con.conname
    SQL
    foreign_keys = fk_rows.map { |name, table, definition| { name: name, table: table, definition: definition } }

    mapping_rows = select_rows(<<~SQL)
      SELECT DISTINCT
        src.relname AS src_table,
        src_att.attname AS src_column,
        dst.relname AS dst_table
      FROM pg_constraint con
      JOIN pg_class src ON src.oid = con.conrelid
      JOIN pg_namespace src_ns ON src_ns.oid = src.relnamespace
      JOIN pg_class dst ON dst.oid = con.confrelid
      CROSS JOIN LATERAL unnest(con.conkey, con.confkey) AS cols(src_attnum, dst_attnum)
      JOIN pg_attribute src_att ON src_att.attrelid = con.conrelid AND src_att.attnum = cols.src_attnum
      JOIN pg_attribute dst_att ON dst_att.attrelid = con.confrelid AND dst_att.attnum = cols.dst_attnum
      WHERE con.contype = 'f'
        AND src_ns.nspname = 'public'
        AND dst.relname IN (#{quoted})
        AND dst_att.attname = 'id'
      ORDER BY src.relname, src_att.attname
    SQL
    fk_column_mappings = mapping_rows.map { |table, column, ref_table| { table: table, column: column, ref_table: ref_table } }

    [ foreign_keys, fk_column_mappings ]
  end

  def build_reference_column_map(target_tables, fk_column_mappings)
    map = Hash.new { |h, k| h[k] = [] }
    fk_column_mappings.each { |m| map[m[:table]] << m[:column] }
    EXPLICIT_NON_FK_REFERENCES.each do |table, col, _|
      map[table] << col if target_tables.include?(table) && column_exists?(table, col)
    end
    POLYMORPHIC_COLUMNS.each do |table, col, _|
      map[table] << col if target_tables.include?(table) && column_exists?(table, col)
    end
    map.transform_values(&:uniq)
  end

  def capture_column_nullability(target_tables, ref_columns_by_table)
    result = {}
    target_tables.each do |table|
      cols = ref_columns_by_table.fetch(table, [])
      next if cols.empty?

      col_list = cols.map { |c| quote(c) }.join(", ")
      select_rows(<<~SQL).each do |col_name, not_null|
        SELECT a.attname, a.attnotnull
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = #{quote(table)}
          AND a.attname IN (#{col_list})
          AND a.attnum > 0
          AND NOT a.attisdropped
      SQL
        result[[ table, col_name ]] = (not_null == true || not_null == "t")
      end
    end
    result
  end

  def capture_check_and_exclusion_constraints(target_tables)
    quoted = target_tables.map { |t| quote(t) }.join(", ")
    rows = select_rows(<<~SQL)
      SELECT
        t.relname,
        con.conname,
        con.contype,
        pg_get_constraintdef(con.oid)
      FROM pg_constraint con
      JOIN pg_class t ON t.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'public'
        AND t.relname IN (#{quoted})
        AND con.contype IN ('c', 'u', 'x')
      ORDER BY t.relname, con.contype, con.conname
    SQL
    rows.map { |table, name, type, definition| { table: table, name: name, type: type, definition: definition } }
  end

  def capture_affected_indexes(target_tables, ref_columns_by_table)
    affected = []
    target_tables.each do |table|
      converted_cols = [ "id" ] + ref_columns_by_table.fetch(table, [])
      rows = select_rows(<<~SQL)
        SELECT
          n.nspname,
          idx_cls.relname,
          pg_get_indexdef(i.indexrelid),
          ARRAY(
            SELECT a.attname
            FROM unnest(i.indkey) WITH ORDINALITY AS k(attnum, ord)
            LEFT JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.attnum
          ) AS col_names
        FROM pg_index i
        JOIN pg_class tbl ON tbl.oid = i.indrelid
        JOIN pg_namespace n ON n.oid = tbl.relnamespace
        JOIN pg_class idx_cls ON idx_cls.oid = i.indexrelid
        WHERE n.nspname = 'public'
          AND tbl.relname = #{quote(table)}
          AND NOT i.indisprimary
          AND NOT EXISTS (SELECT 1 FROM pg_constraint con WHERE con.conindid = i.indexrelid AND con.contype IN ('p', 'u', 'x'))
        ORDER BY idx_cls.relname
      SQL

      rows.each do |schema, idx_name, idx_def, col_names_raw|
        col_names = parse_pg_text_array(col_names_raw)
        touches_converted = (col_names & converted_cols).any? ||
          converted_cols.any? { |c| idx_def.match?(/\b#{Regexp.escape(c)}\b/) }
        next unless touches_converted

        affected << { schema: schema, table: table, name: idx_name, definition: idx_def }
      end
    end
    affected
  end

  def parse_pg_text_array(value)
    return value.compact if value.is_a?(Array)
    return [] if value.nil? || value == "{}"

    value.to_s.delete_prefix("{").delete_suffix("}").split(",").reject { |s| s == "NULL" || s.empty? }.map { |s| s.delete_prefix('"').delete_suffix('"') }
  end

  def resolve_polymorphic_table!(type_name, target_tables)
    if POLYMORPHIC_TABLE_OVERRIDES.key?(type_name)
      table = POLYMORPHIC_TABLE_OVERRIDES.fetch(type_name)
      return table if target_tables.include?(table)
    end

    klass = type_name.safe_constantize
    if klass && klass < ActiveRecord::Base && target_tables.include?(klass.table_name)
      return klass.table_name
    end

    guessed = type_name.underscore.pluralize
    return guessed if target_tables.include?(guessed)

    raise "Cannot map polymorphic type #{type_name.inspect} to any migrated table"
  end

  def verify_no_unmapped!(table, col)
    count = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM #{qt(table)}
      WHERE #{qc(col)} IS NOT NULL AND #{qc(temp_col(col))} IS NULL
    SQL
    raise "Unmapped references in #{table}.#{col}: #{count} rows" if count.positive?
  end

  def remap_live_jsonb_columns(target_tables)
    # Load each referenced table's old-to-new ID map on first use, so every converted table is covered.
    id_maps = Hash.new do |maps, table|
      raise "Cannot remap JSON IDs for unconverted table #{table.inspect}" unless target_tables.include?(table)

      maps[table] = select_rows("SELECT id, __uuid_pk FROM #{qt(table)}").to_h { |old_id, new_id| [ old_id.to_i, new_id ] }
    end

    lookup = lambda do |table, raw_val|
      return raw_val if raw_val.nil?
      return raw_val if raw_val.is_a?(String) && raw_val.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)

      int_val = integer_id_value(raw_val)
      return raw_val unless int_val

      id_maps[table][int_val]
    end

    orphan_uuid = lambda do |table, raw_val|
      int_val = integer_id_value(raw_val)
      return nil unless int_val

      select_value("SELECT pg_temp._aa_uuid_v7_from(TIMESTAMPTZ '2025-01-01 00:00:00+00', #{quote(table)}, #{int_val})")
    end

    lookup_list = lambda do |table, list|
      return list unless list.is_a?(Array)

      list.filter_map { |val| lookup.call(table, val) }
    end

    remap_scope = lambda do |scope|
      return scope unless scope.is_a?(Hash)

      updated = scope.dup
      SCOPE_SINGLE_ID_TABLES.each do |key, tbl|
        next unless updated.key?(key) && !updated[key].nil? && updated[key] != ""

        mapped = lookup.call(tbl, updated[key])
        mapped ? updated[key] = mapped : updated.delete(key)
      end
      SCOPE_ARRAY_ID_TABLES.each do |key, tbl|
        next unless updated[key].is_a?(Array)

        updated[key] = lookup_list.call(tbl, updated[key])
      end
      if updated["quest_progress"].is_a?(Array)
        updated["quest_progress"] = updated["quest_progress"].map do |snapshot|
          next snapshot unless snapshot.is_a?(Hash) && snapshot.key?("goal_id")

          mapped_goal = lookup.call("goals", snapshot["goal_id"]) || orphan_uuid.call("goals", snapshot["goal_id"])
          mapped_goal ? snapshot.merge("goal_id" => mapped_goal) : snapshot
        end
      end
      updated
    end

    remap_question = lambda do |question|
      return question unless question.is_a?(Hash)

      updated = question.dup
      if updated["subject_type"] && updated.key?("subject_id") && !updated["subject_id"].nil?
        subj_tbl = resolve_polymorphic_table!(updated["subject_type"], target_tables)
        updated["subject_id"] = lookup.call(subj_tbl, updated["subject_id"]) || orphan_uuid.call(subj_tbl, updated["subject_id"])
      end
      if updated["target_type"] && updated.key?("target_id") && !updated["target_id"].nil?
        tgt_tbl = resolve_polymorphic_table!(updated["target_type"], target_tables)
        updated["target_id"] = lookup.call(tgt_tbl, updated["target_id"]) || orphan_uuid.call(tgt_tbl, updated["target_id"])
      end
      if updated.key?("team_id") && !updated["team_id"].nil?
        updated["team_id"] = lookup.call("teams", updated["team_id"])
      end
      if updated.key?("season_id") && !updated["season_id"].nil?
        updated["season_id"] = lookup.call("seasons", updated["season_id"])
      end
      if updated["choices"].is_a?(Array) && updated["target_type"]
        tgt_tbl = resolve_polymorphic_table!(updated["target_type"], target_tables)
        updated["choices"] = updated["choices"].map do |choice|
          next choice unless choice.is_a?(Hash) && choice.key?("id") && !choice["id"].nil?

          mapped = lookup.call(tgt_tbl, choice["id"]) || orphan_uuid.call(tgt_tbl, choice["id"])
          mapped ? choice.merge("id" => mapped) : choice
        end
      end
      updated
    end

    # 1. game_rounds (newly_known_player_ids, scope, questions)
    if target_tables.include?("game_rounds")
      select_rows("SELECT id, newly_known_player_ids, scope, questions FROM game_rounds").each do |row_id, known_raw, scope_raw, questions_raw|
        known = parse_json(known_raw)
        scope = parse_json(scope_raw)
        questions = parse_json(questions_raw)

        new_known = lookup_list.call("players", known)
        new_scope = remap_scope.call(scope)
        new_questions = questions.is_a?(Array) ? questions.map { |q| remap_question.call(q) } : questions

        if new_known != known || new_scope != scope || new_questions != questions
          execute <<~SQL
            UPDATE game_rounds
            SET newly_known_player_ids = #{quote(JSON.generate(new_known))}::jsonb,
                scope = #{quote(JSON.generate(new_scope))}::jsonb,
                questions = #{quote(JSON.generate(new_questions))}::jsonb
            WHERE id = #{row_id.to_i}
          SQL
        end
      end
    end

    # 2. practice_reviews (question)
    if target_tables.include?("practice_reviews")
      select_rows("SELECT id, question FROM practice_reviews").each do |row_id, question_raw|
        question = parse_json(question_raw)
        new_question = remap_question.call(question)
        if new_question != question
          execute <<~SQL
            UPDATE practice_reviews
            SET question = #{quote(JSON.generate(new_question))}::jsonb
            WHERE id = #{row_id.to_i}
          SQL
        end
      end
    end

    # 3. goal_achievements (player_ids, required_player_ids, practice_scope)
    if target_tables.include?("goal_achievements")
      select_rows("SELECT id, player_ids, required_player_ids, practice_scope FROM goal_achievements").each do |row_id, pids_raw, req_raw, scope_raw|
        pids = parse_json(pids_raw)
        req = parse_json(req_raw)
        scope = parse_json(scope_raw)

        new_pids = lookup_list.call("players", pids)
        new_req = lookup_list.call("players", req)
        new_scope = remap_scope.call(scope)

        if new_pids != pids || new_req != req || new_scope != scope
          execute <<~SQL
            UPDATE goal_achievements
            SET player_ids = #{quote(JSON.generate(new_pids))}::jsonb,
                required_player_ids = #{quote(JSON.generate(new_req))}::jsonb,
                practice_scope = #{quote(JSON.generate(new_scope))}::jsonb
            WHERE id = #{row_id.to_i}
          SQL
        end
      end
    end

    # 4. game_attempts (options_presented)
    if target_tables.include?("game_attempts")
      select_rows("SELECT id, target_entity_type, options_presented FROM game_attempts WHERE options_presented != '[]'::jsonb").each do |row_id, target_type, opts_raw|
        opts = parse_json(opts_raw)
        next unless opts.is_a?(Array) && opts.any? && target_type.present?

        tgt_tbl = resolve_polymorphic_table!(target_type, target_tables)
        new_opts = lookup_list.call(tgt_tbl, opts)
        if new_opts != opts
          execute <<~SQL
            UPDATE game_attempts
            SET options_presented = #{quote(JSON.generate(new_opts))}::jsonb
            WHERE id = #{row_id.to_i}
          SQL
        end
      end
    end
  end

  def parse_json(raw)
    return raw unless raw.is_a?(String)

    JSON.parse(raw)
  end

  def integer_id_value(raw)
    return raw if raw.is_a?(Integer)
    return raw.to_i if raw.is_a?(String) && raw.match?(/\A\d+\z/)

    nil
  end

  def fk_action(code)
    case code
    when "c" then "CASCADE"
    when "n" then "SET NULL"
    when "d" then "SET DEFAULT"
    when "r" then "RESTRICT"
    else nil
    end
  end

  def verify_no_remaining_integer_ids!(target_tables)
    quoted = target_tables.map { |t| quote(t) }.join(", ")
    remaining = select_rows(<<~SQL)
      SELECT table_name, column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name IN (#{quoted})
        AND (column_name = 'id' OR column_name LIKE '%\\_id')
        AND data_type IN ('smallint', 'integer', 'bigint')
      ORDER BY table_name, column_name
    SQL
    return if remaining.empty?

    details = remaining.map { |t, c, dt| "#{t}.#{c} (#{dt})" }.join(", ")
    raise "Integer ID columns remain after UUID migration: #{details}"
  end
end
