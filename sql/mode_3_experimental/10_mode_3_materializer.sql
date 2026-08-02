-- =========================================================
-- 10_mode_3_materializer.sql
-- DATAGEN MODE 3 - MATERIALIZER
--
-- Purpose:
--   Materialize Mode 3 JSON output into a typed temp table
--   matching the target table's non-surrogate columns.
--
-- Dependencies:
--   - 09_mode_3_engine.sql
--
-- Output temp table:
--   datagen_mode_3_output
-- =========================================================

DROP PROCEDURE IF EXISTS datagen.materialize_mode_3(text, text, integer);

CREATE OR REPLACE PROCEDURE datagen.materialize_mode_3(
    p_schema_name   text,
    p_table_name    text,
    p_expand_factor integer DEFAULT 2
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_regclass regclass;
    v_create_sql     text;
    v_insert_sql     text;
    v_select_list    text;
    v_col_count      integer;
BEGIN
    -- -----------------------------------------------------
    -- input validation
    -- -----------------------------------------------------
    IF p_expand_factor IS NULL OR p_expand_factor < 1 THEN
        RAISE EXCEPTION 'p_expand_factor must be >= 1';
    END IF;

    v_table_regclass := to_regclass(format('%I.%I', p_schema_name, p_table_name));

    IF v_table_regclass IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    -- -----------------------------------------------------
    -- dependency guard
    -- -----------------------------------------------------
    IF to_regprocedure('datagen.mode_3(text, text, integer)') IS NULL THEN
        RAISE EXCEPTION 'Required function datagen.mode_3(text, text, integer) does not exist. Run 09_mode_3_engine.sql first.';
    END IF;

    DROP TABLE IF EXISTS datagen_mode_3_output;

    WITH cols AS
    (
        SELECT
            c.ordinal_position,
            c.column_name,
            c.data_type,
            c.udt_name,
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
    ),
    usable_cols AS
    (
        SELECT *
        FROM cols
        WHERE NOT is_surrogate_id
    )
    SELECT
        COUNT(*),
        'CREATE TABLE datagen_mode_3_output (' ||
        string_agg(
            format(
                '%I %s',
                column_name,
                CASE
                    WHEN data_type = 'USER-DEFINED' THEN udt_name
                    WHEN data_type = 'ARRAY' THEN udt_name
                    ELSE data_type
                END
            ),
            ', ' ORDER BY ordinal_position
        ) ||
        ');',
        string_agg(
            format(
                CASE
                    WHEN data_type = 'boolean' THEN
                        '(resolved_payload->>%L)::boolean AS %I'
                    WHEN data_type IN ('integer', 'bigint', 'smallint') THEN
                        '(resolved_payload->>%L)::%s AS %I'
                    WHEN data_type IN ('numeric', 'real', 'double precision') THEN
                        '(resolved_payload->>%L)::%s AS %I'
                    WHEN data_type = 'date' THEN
                        '(resolved_payload->>%L)::date AS %I'
                    ELSE
                        'resolved_payload->>%L AS %I'
                END,
                column_name,
                CASE
                    WHEN data_type IN (
                        'integer', 'bigint', 'smallint',
                        'numeric', 'real', 'double precision'
                    )
                    THEN data_type
                    ELSE column_name
                END,
                column_name
            ),
            ', ' ORDER BY ordinal_position
        )
    INTO v_col_count, v_create_sql, v_select_list
    FROM usable_cols;

    IF v_col_count = 0 THEN
        RAISE EXCEPTION 'No usable non-surrogate columns found for %.%', p_schema_name, p_table_name;
    END IF;

    EXECUTE v_create_sql;

    v_insert_sql := format(
        'INSERT INTO datagen_mode_3_output
         SELECT %s
         FROM datagen.mode_3(%L, %L, %s);',
        v_select_list,
        p_schema_name,
        p_table_name,
        p_expand_factor
    );

    EXECUTE v_insert_sql;
END;
$$;

-- =========================================================
-- OPTIONAL EXAMPLE CALLS
-- =========================================================

-- CALL datagen.materialize_mode_3('public', 'transactions', 5);
-- SELECT * FROM datagen_mode_3_output;