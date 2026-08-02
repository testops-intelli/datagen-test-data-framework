-- =========================================================
-- 05_mode_2.sql
-- DATAGEN MODE 2
--
-- Purpose:
--   Resolve Mode 1's placeholder param space using real
--   historical tuples pulled from the target table itself,
--   scaled by a multiplier.
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
--   2) Mode_2 identifies every currently-unresolved column and
--      treats them as ONE tuple (not resolved independently
--      per column) -- pulling DISTINCT whole-row combinations
--      of exactly those columns as they actually occurred
--      together historically. This is the strongest possible
--      relational-integrity guarantee: it's literally rows
--      that co-occurred.
--   3) Distinct historical tuples are ordered deterministically
--      by the unresolved columns in their natural (ordinal)
--      table order.
--   4) p_multiplier controls how many "passes" of the base
--      param space to generate:
--        - pass 1 resolves every row of the base param space
--          using the 1st distinct historical tuple
--        - pass 2 uses the 2nd distinct historical tuple
--        - ... pass N uses the Nth
--   5) If fewer than p_multiplier distinct historical tuples
--      exist, generation stops there -- no repeating a tuple,
--      no partial rows. Effective multiplier is capped at the
--      available distinct tuple count.
--
-- Output:
--   - datagen.mode_2(...) returns JSON rows
--   - datagen.materialize_mode_2(...) creates an inspectable
--     temp table with real column types
-- =========================================================


-- =========================================================
-- DROP OLD OBJECTS
-- =========================================================
DROP PROCEDURE IF EXISTS datagen.materialize_mode_2(text, text, integer);
DROP FUNCTION  IF EXISTS datagen.mode_2(text, text, integer);


-- =========================================================
-- CORE FUNCTION: MODE 2
--
-- Inputs:
--   p_schema_name
--   p_table_name
--   p_multiplier   -- how many passes of the base param space
--                      to generate (each pass resolved with
--                      the next distinct historical tuple)
--
-- Output:
--   row_no
--   resolved_payload jsonb
--
-- Example:
--   SELECT * FROM datagen.mode_2('public', 'transactions', 2);
-- =========================================================
CREATE OR REPLACE FUNCTION datagen.mode_2(
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
    v_unresolved_sql text;
    v_final_sql      text;
BEGIN
    IF p_multiplier IS NULL OR p_multiplier < 1 THEN
        RAISE EXCEPTION 'p_multiplier must be >= 1';
    END IF;

    v_table_regclass := to_regclass(format('%I.%I', p_schema_name, p_table_name));

    IF v_table_regclass IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    -- -----------------------------------------------------
    -- Build dynamic SQL for the DISTINCT historical tuples
    -- across exactly the unresolved columns, ordered by
    -- those same columns in natural (ordinal) table order,
    -- numbered 1..N for pass indexing.
    -- -----------------------------------------------------
    WITH column_meta AS
    (
        SELECT
            c.ordinal_position,
            c.column_name,
            c.data_type,
            c.column_default,
            (c.is_identity = 'YES') AS is_identity,
            datagen.get_check_domain(v_table_regclass, c.column_name) AS check_domain,
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
    ),
    unresolved_cols AS
    (
        SELECT ordinal_position, column_name
        FROM column_meta
        WHERE NOT is_surrogate_id
          AND NOT (data_type = 'boolean' OR check_domain IS NOT NULL)
        ORDER BY ordinal_position
    )
    SELECT
        CASE
            WHEN COUNT(*) = 0 THEN NULL
            ELSE
                'SELECT row_number() OVER (ORDER BY ' ||
                string_agg(format('t.%I', column_name), ', ' ORDER BY ordinal_position) ||
                ') AS pass_no, jsonb_build_object(' ||
                string_agg(format('%L, t.%I', column_name, column_name), ', ' ORDER BY ordinal_position) ||
                ') AS tuple_payload ' ||
                'FROM (SELECT DISTINCT ' ||
                string_agg(format('%I', column_name), ', ' ORDER BY ordinal_position) ||
                format(' FROM %I.%I) t', p_schema_name, p_table_name)
        END
    INTO v_unresolved_sql
    FROM unresolved_cols;

    -- -----------------------------------------------------
    -- No unresolved columns: Mode_2 collapses to Mode_1(false)
    -- semantics, ignoring p_multiplier (nothing to resolve or
    -- multiply).
    -- -----------------------------------------------------
    IF v_unresolved_sql IS NULL THEN
        RETURN QUERY
        SELECT
            row_number() OVER (ORDER BY m.combo_payload::text)::bigint AS row_no,
            m.combo_payload AS resolved_payload
        FROM datagen.mode_1(p_schema_name, p_table_name, false) m
        ORDER BY 1;

        RETURN;
    END IF;

    -- -----------------------------------------------------
    -- Main resolution pipeline: cross the base param space
    -- with only as many distinct historical tuples as are
    -- actually available, capped at p_multiplier.
    -- -----------------------------------------------------
    v_final_sql := format(
        $sql$
        WITH base AS (
            SELECT combo_no, combo_payload
            FROM datagen.mode_1(%L, %L, true)
        ),
        hist_tuples AS (%s),
        capped_tuples AS (
            SELECT pass_no, tuple_payload
            FROM hist_tuples
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
        v_unresolved_sql,
        p_multiplier
    );

    RETURN QUERY EXECUTE v_final_sql;
END;
$$;


-- =========================================================
-- MATERIALIZER: MODE 2 TABLE OUTPUT
--
-- Creates temp table:
--   datagen_mode_2_output
--
-- All columns materialized as TEXT: bool/enum columns are
-- always resolved by Mode 1, but the historical-tuple columns
-- could in principle include NULLs from the source table, and
-- a uniform TEXT output keeps this proc simple and safe.
-- =========================================================
CREATE OR REPLACE PROCEDURE datagen.materialize_mode_2(
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

    DROP TABLE IF EXISTS datagen_mode_2_output;

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
        'CREATE TEMP TABLE datagen_mode_2_output (' ||
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
        v_create_sql := 'CREATE TEMP TABLE datagen_mode_2_output ();';
    END IF;

    EXECUTE v_create_sql;

    IF v_select_list IS NOT NULL THEN
        v_insert_sql := format(
            'INSERT INTO datagen_mode_2_output
             SELECT %s
             FROM datagen.mode_2(%L, %L, %s);',
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
-- SELECT * FROM datagen.mode_2('public', 'transactions', 2);

-- Materialized table
-- CALL datagen.materialize_mode_2('public', 'transactions', 2);
-- SELECT * FROM datagen_mode_2_output;
