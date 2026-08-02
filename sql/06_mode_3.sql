-- =========================================================
-- 06_mode_3.sql
-- DATAGEN MODE 3
--
-- Purpose:
--   Resolve Mode 1's placeholder param space using a
--   user-supplied candidates table, registered per target
--   table in a metadata lookup table, scaled by a multiplier.
--
-- Dependencies:
--   - 01_schema.sql
--   - 02_seed_demo_data.sql
--   - 03_core_helpers.sql
--   - 04_mode_1.sql
-- =========================================================
--
-- Behaviour:
--   1) Mode_1(true) produces the deterministic param space
--      with placeholders (@column_name) for every unresolved
--      column.
--   2) datagen.mode_3_resolution_map is a one-row-per-table
--      registry: for a given target table, it names exactly
--      which placeholder columns should be resolved, and
--      which single user-supplied candidates table holds the
--      legal values for ALL of them together, as one tuple.
--      (Curating what belongs in that candidates table --
--      including which columns should travel together as a
--      valid combination -- is the caller's responsibility;
--      Mode 3 only wires it in and validates the columns
--      exist.)
--   3) Candidate rows are ordered deterministically by the
--      resolved columns in their natural (declared) order in
--      placeholder_columns_json.
--   4) p_multiplier controls how many "passes" of the base
--      param space to generate:
--        - pass 1 resolves every row of the base param space
--          using the 1st candidate row
--        - pass 2 uses the 2nd candidate row
--        - ... pass N uses the Nth
--   5) If fewer than p_multiplier candidate rows exist,
--      generation stops there -- no repeating a row. Effective
--      multiplier is capped at the available candidate row
--      count.
--
-- Output:
--   - datagen.mode_3(...) returns JSON rows
--   - datagen.materialize_mode_3(...) creates an inspectable
--     temp table with real column types
-- =========================================================


-- =========================================================
-- DROP OLD OBJECTS
-- =========================================================
DROP PROCEDURE IF EXISTS datagen.materialize_mode_3(text, text, integer);
DROP FUNCTION  IF EXISTS datagen.mode_3(text, text, integer);


-- =========================================================
-- REGISTRY: MODE 3 RESOLUTION MAP
--
-- One row per target table.
--
-- placeholder_columns_json:
--   JSON array of target-table column names to resolve, in
--   the exact order candidate rows should be matched to them,
--   e.g. '["company_id","trade_date","description"]'
--
-- candidates_schema_name / candidates_table_name:
--   the user-supplied table holding legal value combinations.
--   Must expose columns named identically to every entry in
--   placeholder_columns_json (validated at run time).
-- =========================================================
DROP TABLE IF EXISTS datagen.mode_3_resolution_map CASCADE;

CREATE TABLE datagen.mode_3_resolution_map (
    target_schema_name       TEXT    NOT NULL,
    target_table_name        TEXT    NOT NULL,
    placeholder_columns_json JSONB   NOT NULL,
    candidates_schema_name   TEXT    NOT NULL,
    candidates_table_name    TEXT    NOT NULL,
    is_active                BOOLEAN NOT NULL DEFAULT TRUE,
    notes                    TEXT    NULL,
    PRIMARY KEY (target_schema_name, target_table_name)
);


-- =========================================================
-- CORE FUNCTION: MODE 3
--
-- Inputs:
--   p_schema_name
--   p_table_name
--   p_multiplier   -- how many passes of the base param space
--                      to generate (each pass resolved with
--                      the next candidate row)
--
-- Output:
--   row_no
--   resolved_payload jsonb
--
-- Example:
--   SELECT * FROM datagen.mode_3('public', 'transactions', 2);
-- =========================================================
CREATE OR REPLACE FUNCTION datagen.mode_3(
    p_schema_name  text,
    p_table_name   text,
    p_multiplier   integer DEFAULT 1
)
RETURNS TABLE
(
    row_no            bigint,
    resolved_payload  jsonb
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_table_regclass regclass;
    v_cand_regclass  regclass;
    v_reg            RECORD;
    v_cols_array     text[];
    v_missing_cols   text[];
    v_select_cols    text;
    v_order_cols     text;
    v_cand_sql       text;
    v_final_sql      text;
BEGIN
    IF p_multiplier IS NULL OR p_multiplier < 1 THEN
        RAISE EXCEPTION 'p_multiplier must be >= 1';
    END IF;

    v_table_regclass := to_regclass(format('%I.%I', p_schema_name, p_table_name));

    IF v_table_regclass IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    SELECT *
    INTO v_reg
    FROM datagen.mode_3_resolution_map
    WHERE target_schema_name = p_schema_name
      AND target_table_name  = p_table_name
      AND is_active;

    -- -----------------------------------------------------
    -- No registry entry: Mode_3 collapses to Mode_1(true)
    -- semantics -- nothing registered to resolve, everything
    -- stays placeheld.
    -- -----------------------------------------------------
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            row_number() OVER (ORDER BY m.combo_payload::text)::bigint AS row_no,
            m.combo_payload AS resolved_payload
        FROM datagen.mode_1(p_schema_name, p_table_name, true) m
        ORDER BY 1;

        RETURN;
    END IF;

    v_cand_regclass := to_regclass(
        format('%I.%I', v_reg.candidates_schema_name, v_reg.candidates_table_name)
    );

    IF v_cand_regclass IS NULL THEN
        RAISE EXCEPTION
            'Mode 3: candidates table %.% (registered for %.%) does not exist',
            v_reg.candidates_schema_name, v_reg.candidates_table_name,
            p_schema_name, p_table_name;
    END IF;

    SELECT array_agg(value)
    INTO v_cols_array
    FROM jsonb_array_elements_text(v_reg.placeholder_columns_json);

    IF v_cols_array IS NULL OR array_length(v_cols_array, 1) = 0 THEN
        RAISE EXCEPTION
            'Mode 3: placeholder_columns_json is empty for %.%',
            p_schema_name, p_table_name;
    END IF;

    SELECT array_agg(col)
    INTO v_missing_cols
    FROM unnest(v_cols_array) AS col
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.columns ic
        WHERE ic.table_schema = v_reg.candidates_schema_name
          AND ic.table_name   = v_reg.candidates_table_name
          AND ic.column_name  = col
    );

    IF v_missing_cols IS NOT NULL THEN
        RAISE EXCEPTION
            'Mode 3: candidates table %.% is missing column(s) required for %.%: %',
            v_reg.candidates_schema_name, v_reg.candidates_table_name,
            p_schema_name, p_table_name,
            array_to_string(v_missing_cols, ', ');
    END IF;

    SELECT string_agg(format('%L, c.%I', col, col), ', ')
    INTO v_select_cols
    FROM unnest(v_cols_array) AS col;

    -- Ordered by the resolved columns in their natural
    -- (declared) placeholder order -- deterministic pass
    -- numbering.
    SELECT string_agg(format('c.%I', col), ', ')
    INTO v_order_cols
    FROM unnest(v_cols_array) AS col;

    v_cand_sql := format(
        'SELECT row_number() OVER (ORDER BY %s) AS pass_no, jsonb_build_object(%s) AS tuple_payload
         FROM %I.%I c',
        v_order_cols,
        v_select_cols,
        v_reg.candidates_schema_name,
        v_reg.candidates_table_name
    );

    v_final_sql := format(
        $sql$
        WITH base AS (
            SELECT combo_no, combo_payload
            FROM datagen.mode_1(%L, %L, true)
        ),
        cand_tuples AS (%s),
        capped_tuples AS (
            SELECT pass_no, tuple_payload
            FROM cand_tuples
            WHERE pass_no <= %s
        )
        SELECT
            row_number() OVER (ORDER BY capped_tuples.pass_no, base.combo_no)::bigint AS row_no,
            (base.combo_payload || capped_tuples.tuple_payload) AS resolved_payload
        FROM base
        CROSS JOIN capped_tuples
        ORDER BY 1
        $sql$,
        p_schema_name,
        p_table_name,
        v_cand_sql,
        p_multiplier
    );

    RETURN QUERY EXECUTE v_final_sql;
END;
$$;


-- =========================================================
-- MATERIALIZER: MODE 3 TABLE OUTPUT
--
-- Creates temp table:
--   datagen_mode_3_output
--
-- All columns materialized as TEXT for the same reason as
-- Mode 2's materializer.
-- =========================================================
CREATE OR REPLACE PROCEDURE datagen.materialize_mode_3(
    p_schema_name text,
    p_table_name  text,
    p_multiplier  integer DEFAULT 1
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_regclass regclass;
    v_create_sql     text;
    v_insert_sql     text;
    v_select_list    text;
BEGIN
    IF p_multiplier IS NULL OR p_multiplier < 1 THEN
        RAISE EXCEPTION 'p_multiplier must be >= 1';
    END IF;

    v_table_regclass := to_regclass(format('%I.%I', p_schema_name, p_table_name));

    IF v_table_regclass IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    DROP TABLE IF EXISTS datagen_mode_3_output;

    WITH cols AS
    (
        SELECT
            c.ordinal_position,
            c.column_name,
            c.column_default,
            (c.is_identity = 'YES') AS is_identity,
            CASE
                WHEN c.is_identity = 'YES' THEN TRUE
                WHEN c.column_default LIKE 'nextval(%' THEN TRUE
                WHEN lower(c.column_name) = 'id' THEN TRUE
                WHEN lower(c.column_name) = lower(p_table_name) || '_id' THEN TRUE
                ELSE FALSE
            END AS is_surrogate_id
        FROM information_schema.columns c
        WHERE c.table_schema = p_schema_name
          AND c.table_name   = p_table_name
    )
    SELECT
        'CREATE TEMP TABLE datagen_mode_3_output (' ||
        string_agg(format('%I text', column_name), ', ' ORDER BY ordinal_position) ||
        ');',
        string_agg(
            format('resolved_payload->>%L AS %I', column_name, column_name),
            ', ' ORDER BY ordinal_position
        )
    INTO v_create_sql, v_select_list
    FROM cols
    WHERE NOT is_surrogate_id;

    IF v_create_sql IS NULL THEN
        v_create_sql := 'CREATE TEMP TABLE datagen_mode_3_output ();';
    END IF;

    EXECUTE v_create_sql;

    IF v_select_list IS NOT NULL THEN
        v_insert_sql := format(
            'INSERT INTO datagen_mode_3_output
             SELECT %s
             FROM datagen.mode_3(%L, %L, %s);',
            v_select_list,
            p_schema_name,
            p_table_name,
            p_multiplier
        );

        EXECUTE v_insert_sql;
    END IF;
END;
$$;


-- =========================================================
-- EXAMPLE CALLS
-- =========================================================

-- JSON engine
-- SELECT * FROM datagen.mode_3('public', 'transactions', 2);

-- Materialized table
-- CALL datagen.materialize_mode_3('public', 'transactions', 2);
-- SELECT * FROM datagen_mode_3_output;

-- Registering a candidates table for another target table:
-- INSERT INTO datagen.mode_3_resolution_map (
--     target_schema_name, target_table_name,
--     placeholder_columns_json,
--     candidates_schema_name, candidates_table_name
-- ) VALUES (
--     'public', 'my_table',
--     '["fk_col_a","fk_col_b","free_text_col"]'::jsonb,
--     'datagen', 'my_table_candidates'
-- );
