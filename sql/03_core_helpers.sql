
--03_core_helpers.sql

CREATE SCHEMA IF NOT EXISTS datagen;

-- =========================================================
-- HELPER: EXTRACT CHECK DOMAIN
--
-- Supports simple single-column finite quoted-value checks, e.g.
--   CHECK (status IN ('Active', 'Inactive'))
--   CHECK ((status = ANY (ARRAY['Active'::text, 'Inactive'::text])))
-- =========================================================

DROP FUNCTION IF EXISTS datagen.get_check_domain(regclass, text);

CREATE OR REPLACE FUNCTION datagen.get_check_domain(
    p_table_regclass regclass,
    p_column_name    text
)
RETURNS text[]
LANGUAGE sql
STABLE
AS $$
    WITH defs AS
    (
        SELECT pg_get_constraintdef(c.oid, true) AS constraint_def
        FROM pg_constraint c
        JOIN pg_attribute a
          ON a.attrelid = c.conrelid
         AND a.attnum   = ANY (c.conkey)
        WHERE c.conrelid = p_table_regclass
          AND c.contype  = 'c'
          AND array_length(c.conkey, 1) = 1
          AND a.attname = p_column_name
          AND pg_get_constraintdef(c.oid, true) ~* '(= ANY\s*\(ARRAY| IN \()'
    ),
    vals AS
    (
        SELECT DISTINCT replace(m[1], '''''', '''') AS val
        FROM defs d
        CROSS JOIN LATERAL regexp_matches(
            d.constraint_def,
            '''((?:[^'']|'''')*)''',
            'g'
        ) AS m
    )
    SELECT CASE
             WHEN EXISTS (SELECT 1 FROM vals)
             THEN array_agg(val ORDER BY val)
             ELSE NULL
           END
    FROM vals;
$$;