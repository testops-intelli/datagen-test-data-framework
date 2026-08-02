-- =========================================================
-- 04_mode_1.sql
-- DATAGEN MODE 1
--
-- Includes:
--   1) core function: datagen.mode_1
--   2) materializer proc: with placeholders
--   3) materializer proc: without placeholders
--
-- Dependencies:
--   - 01_schema.sql
--   - 02_seed_demo_data.sql
--   - 03_core_helpers.sql
--     -- Requires datagen.get_check_domain(...) from 03_core_helpers.sql
-- =========================================================

-- =========================================================
-- DROP OLD OBJECTS
-- =========================================================
DROP PROCEDURE IF EXISTS datagen.materialize_mode_1_with_placeholders(text, text);
DROP PROCEDURE IF EXISTS datagen.materialize_mode_1_with_placeholders(text, text, text);

DROP PROCEDURE IF EXISTS datagen.materialize_mode_1_without_placeholders(text, text);
DROP PROCEDURE IF EXISTS datagen.materialize_mode_1_without_placeholders(text, text, text);

DROP PROCEDURE IF EXISTS datagen.materialize_mode_1(text, text, boolean, text);


-- =========================================================
-- CORE FUNCTION: MODE 1
--
-- Inputs:
--   p_schema_name
--   p_table_name
--   p_show_placeholders
--
-- Output:
--   combo_no
--   combo_payload (jsonb)
--
-- Rules:
--   - deterministic columns:
--       * boolean
--       * simple single-column check finite domains
--   - unresolved columns:
--       * included as "@column_name" only if p_show_placeholders = true
--   - surrogate/internal IDs:
--       * excluded entirely
-- =========================================================

DROP FUNCTION IF EXISTS datagen.mode_1(text, text, boolean);

CREATE OR REPLACE FUNCTION datagen.mode_1(
    p_schema_name       text,
    p_table_name        text,
    p_show_placeholders boolean DEFAULT true
)
RETURNS TABLE
(
    combo_no      bigint,
    combo_payload jsonb
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_table_regclass regclass;
BEGIN
    v_table_regclass := to_regclass(format('%I.%I', p_schema_name, p_table_name));

    IF v_table_regclass IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    RETURN QUERY
    WITH RECURSIVE
    column_meta AS
    (
        SELECT
            c.ordinal_position,
            c.column_name,
            c.data_type,
            c.udt_name,
            (c.is_nullable = 'YES') AS is_nullable,
            c.column_default,
            (c.is_identity = 'YES') AS is_identity,
            cd.check_domain,

            CASE
                WHEN c.is_identity = 'YES' THEN TRUE
                WHEN c.column_default LIKE 'nextval(%' THEN TRUE
                WHEN lower(c.column_name) = 'id' THEN TRUE
                WHEN lower(c.column_name) = lower(p_table_name) || '_id' THEN TRUE
                ELSE FALSE
            END AS is_surrogate_id
        FROM information_schema.columns c
        LEFT JOIN LATERAL
        (
            SELECT datagen.get_check_domain(v_table_regclass, c.column_name) AS check_domain
        ) cd ON TRUE
        WHERE c.table_schema = p_schema_name
          AND c.table_name   = p_table_name
    ),
    filtered_columns AS
    (
        SELECT
            ordinal_position,
            column_name,
            data_type,
            udt_name,
            is_nullable,
            column_default,
            is_identity,
            is_surrogate_id,
            check_domain,

            CASE
                WHEN data_type = 'boolean' THEN TRUE
                WHEN check_domain IS NOT NULL THEN TRUE
                ELSE FALSE
            END AS is_deterministic,

            CASE
                WHEN data_type = 'boolean' THEN ARRAY['false', 'true']::text[]
                WHEN check_domain IS NOT NULL THEN check_domain
                WHEN NOT is_surrogate_id AND p_show_placeholders THEN ARRAY['@' || column_name]::text[]
                ELSE NULL::text[]
            END AS domain_values
        FROM column_meta
        WHERE NOT is_surrogate_id
    ),
    active_columns AS
    (
        SELECT
            row_number() OVER (ORDER BY ordinal_position)::bigint AS rn,
            ordinal_position,
            column_name,
            data_type,
            domain_values
        FROM filtered_columns
        WHERE domain_values IS NOT NULL
    ),
    max_rn AS
    (
        SELECT COALESCE(MAX(rn), 0::bigint) AS mx
        FROM active_columns
    ),
    combos AS
    (
        SELECT
            0::bigint AS rn,
            '{}'::jsonb AS combo_payload

        UNION ALL

        SELECT
            ac.rn,
            c.combo_payload ||
            jsonb_build_object(
                ac.column_name,
                CASE
                    WHEN ac.data_type = 'boolean'
                         AND u.val IN ('true', 'false')
                    THEN to_jsonb(u.val::boolean)
                    ELSE to_jsonb(u.val)
                END
            ) AS combo_payload
        FROM combos c
        JOIN active_columns ac
          ON ac.rn = c.rn + 1
        CROSS JOIN LATERAL unnest(ac.domain_values) AS u(val)
    )
    SELECT
        row_number() OVER (ORDER BY combos.combo_payload::text)::bigint AS combo_no,
        combos.combo_payload
    FROM combos
    CROSS JOIN max_rn
    WHERE combos.rn = max_rn.mx
    ORDER BY combo_no;

END;
$$;


-- =========================================================
-- MATERIALIZER: WITH PLACEHOLDERS
--
-- Creates temp table:
--   datagen_mode_1_with_placeholders
--
-- All columns materialized as TEXT for safe inspection.
-- =========================================================
CREATE OR REPLACE PROCEDURE datagen.materialize_mode_1_with_placeholders(
    p_schema_name text,
    p_table_name  text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_regclass regclass;
    v_create_sql     text;
    v_insert_sql     text;
    v_select_list    text;
BEGIN
    v_table_regclass := to_regclass(format('%I.%I', p_schema_name, p_table_name));

    IF v_table_regclass IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    DROP TABLE IF EXISTS datagen_mode_1_with_placeholders;

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
        'CREATE TEMP TABLE datagen_mode_1_with_placeholders (' ||
        string_agg(format('%I text', column_name), ', ' ORDER BY ordinal_position) ||
        ');',
        string_agg(
            format('combo_payload->>%L AS %I', column_name, column_name),
            ', ' ORDER BY ordinal_position
        )
    INTO v_create_sql, v_select_list
    FROM cols
    WHERE NOT is_surrogate_id;

    IF v_create_sql IS NULL THEN
        v_create_sql := 'CREATE TEMP TABLE datagen_mode_1_with_placeholders ();';
    END IF;

    EXECUTE v_create_sql;

    IF v_select_list IS NOT NULL THEN
        v_insert_sql := format(
            'INSERT INTO datagen_mode_1_with_placeholders
             SELECT %s
             FROM datagen.mode_1(%L, %L, true);',
            v_select_list,
            p_schema_name,
            p_table_name
        );

        EXECUTE v_insert_sql;
    END IF;
END;
$$;


-- =========================================================
-- MATERIALIZER: WITHOUT PLACEHOLDERS
--
-- Creates temp table:
--   datagen_mode_1_without_placeholders
--
-- Only deterministic columns are included.
-- BOOLEAN stays BOOLEAN.
-- CHECK-domain columns are materialized as TEXT.
-- =========================================================
CREATE OR REPLACE PROCEDURE datagen.materialize_mode_1_without_placeholders(
    p_schema_name text,
    p_table_name  text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_regclass regclass;
    v_create_sql     text;
    v_insert_sql     text;
    v_select_list    text;
BEGIN
    v_table_regclass := to_regclass(format('%I.%I', p_schema_name, p_table_name));

    IF v_table_regclass IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    DROP TABLE IF EXISTS datagen_mode_1_without_placeholders;

    WITH cols AS
    (
        SELECT
            c.ordinal_position,
            c.column_name,
            c.data_type,
            c.udt_name,
            datagen.get_check_domain(v_table_regclass, c.column_name) AS check_domain
        FROM information_schema.columns c
        WHERE c.table_schema = p_schema_name
          AND c.table_name   = p_table_name
    ),
    deterministic_cols AS
    (
        SELECT *
        FROM cols
        WHERE data_type = 'boolean'
           OR check_domain IS NOT NULL
    )
    SELECT
        'CREATE TEMP TABLE datagen_mode_1_without_placeholders (' ||
        string_agg(
            format(
                '%I %s',
                column_name,
                CASE
                    WHEN data_type = 'boolean' THEN 'boolean'
                    ELSE 'text'
                END
            ),
            ', ' ORDER BY ordinal_position
        ) ||
        ');',
        string_agg(
            format(
                CASE
                    WHEN data_type = 'boolean' THEN '(combo_payload->>%L)::boolean AS %I'
                    ELSE 'combo_payload->>%L AS %I'
                END,
                column_name,
                column_name
            ),
            ', ' ORDER BY ordinal_position
        )
    INTO v_create_sql, v_select_list
    FROM deterministic_cols;

    IF v_create_sql IS NULL THEN
        v_create_sql := 'CREATE TEMP TABLE datagen_mode_1_without_placeholders ();';
    END IF;

    EXECUTE v_create_sql;

    IF v_select_list IS NOT NULL THEN
        v_insert_sql := format(
            'INSERT INTO datagen_mode_1_without_placeholders
             SELECT %s
             FROM datagen.mode_1(%L, %L, false);',
            v_select_list,
            p_schema_name,
            p_table_name
        );

        EXECUTE v_insert_sql;
    END IF;
END;
$$;

-- =========================================================
-- EXAMPLE CALLS
-- =========================================================

-- JSON engine
 --SELECT *
 --FROM datagen.mode_1('public', 'transactions', true);

-- Materialized outputs
 --CALL datagen.materialize_mode_1_with_placeholders('public', 'transactions');
 --SELECT * FROM datagen_mode_1_with_placeholders;

 --CALL datagen.materialize_mode_1_without_placeholders('public', 'transactions');
 --SELECT * FROM datagen_mode_1_without_placeholders;

 