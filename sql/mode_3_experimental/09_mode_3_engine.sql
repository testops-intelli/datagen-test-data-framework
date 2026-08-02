-- =========================================================
-- 09_mode_3_engine.sql
-- DATAGEN MODE 3 - JSON ENGINE
--
-- Purpose:
--   Resolve Mode 1 placeholder param space using selected
--   feasible anchors and simple guest-fill rules.
--
-- Current scope:
--   - v1 supports target tables that align with the current
--     guest-fill logic
--   - primary demo target is public.transactions
--
-- Dependencies:
--   - 04_mode_1.sql
--   - 06_mode_3_setup.sql
--   - 08_mode_3_anchor_selector.sql
--
-- Notes:
--   - anchor columns overwrite placeholders
--   - optional guest-fill is applied only when matching target
--     columns exist
-- =========================================================

DROP FUNCTION IF EXISTS datagen.mode_3(text, text, integer);

CREATE OR REPLACE FUNCTION datagen.mode_3(
    p_schema_name   text,
    p_table_name    text,
    p_expand_factor integer DEFAULT 2
)
RETURNS TABLE
(
    row_no           bigint,
    resolved_payload jsonb
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_table_regclass regclass;
    v_has_broker_code boolean;
    v_has_description boolean;
    v_has_units       boolean;
    v_sql             text;
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
    -- dependency guards
    -- -----------------------------------------------------
    IF to_regprocedure('datagen.mode_1(text, text, boolean)') IS NULL THEN
        RAISE EXCEPTION 'mode_1 not found. Run Mode 1 setup first.';
    END IF;

    IF to_regprocedure('datagen.mode_3_select_anchors(text, text, integer)') IS NULL THEN
        RAISE EXCEPTION 'mode_3_select_anchors not found. Run Mode 3 setup first.';
    END IF;

    -- -----------------------------------------------------
    -- column detection
    -- -----------------------------------------------------
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = p_schema_name
          AND table_name   = p_table_name
          AND column_name  = 'broker_code'
    ) INTO v_has_broker_code;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = p_schema_name
          AND table_name   = p_table_name
          AND column_name  = 'description'
    ) INTO v_has_description;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = p_schema_name
          AND table_name   = p_table_name
          AND column_name  = 'units'
    ) INTO v_has_units;

    -- -----------------------------------------------------
    -- dynamic SQL
    -- -----------------------------------------------------
    v_sql := format(
$SQL$
WITH mode1 AS
(
    SELECT combo_no, combo_payload
    FROM datagen.mode_1(%L, %L, true)
),
anchors AS
(
    SELECT *
    FROM datagen.mode_3_select_anchors(%L, %L, %s)
),

-- -----------------------------------------------------
-- guest pools WITH COUNTS (important)
-- -----------------------------------------------------
broker_pool AS
(
    SELECT row_number() OVER (ORDER BY x.broker_code)::bigint AS seq_no,
           x.broker_code
    FROM (SELECT DISTINCT broker_code FROM %I.%I WHERE broker_code IS NOT NULL) x
),
broker_count AS (SELECT COUNT(*)::bigint AS cnt FROM broker_pool),

description_pool AS
(
    SELECT row_number() OVER (ORDER BY x.description)::bigint AS seq_no,
           x.description
    FROM (SELECT DISTINCT description FROM %I.%I WHERE description IS NOT NULL) x
),
description_count AS (SELECT COUNT(*)::bigint AS cnt FROM description_pool),

units_pool AS
(
    SELECT row_number() OVER (ORDER BY x.units)::bigint AS seq_no,
           x.units
    FROM (SELECT DISTINCT units FROM %I.%I WHERE units IS NOT NULL) x
),
units_count AS (SELECT COUNT(*)::bigint AS cnt FROM units_pool),

base_rows AS
(
    SELECT
        row_number() OVER (ORDER BY m.combo_no, a.anchor_no)::bigint AS row_no,
        m.combo_payload,
        a.*
    FROM mode1 m
    CROSS JOIN anchors a
),

guest_ready AS
(
    SELECT
        b.row_no,
        b.combo_payload
        || jsonb_build_object(
            'company_id',  b.company_id,
            'trade_date',  b.trade_date,
            'security_id', b.security_id,
            'currency_id', b.currency_id
        ) AS payload
    FROM base_rows b
),

final_rows AS
(
    SELECT
        g.row_no,
        g.payload

        %s
        %s
        %s

        AS resolved_payload
    FROM guest_ready g
)

SELECT row_no, resolved_payload
FROM final_rows
ORDER BY row_no
$SQL$,

        p_schema_name,
        p_table_name,
        p_schema_name,
        p_table_name,
        p_expand_factor,
        p_schema_name,
        p_table_name,
        p_schema_name,
        p_table_name,
        p_schema_name,
        p_table_name,

        -- broker
        CASE WHEN v_has_broker_code THEN
            '|| jsonb_build_object(' ||
            '''broker_code'', (' ||
            'SELECT bp.broker_code FROM broker_pool bp, broker_count bc ' ||
            'WHERE bc.cnt > 0 AND bp.seq_no = 1 + mod(g.row_no - 1, bc.cnt)' ||
            '))'
        ELSE '' END,

        -- description
        CASE WHEN v_has_description THEN
            '|| jsonb_build_object(' ||
            '''description'', (' ||
            'SELECT dp.description FROM description_pool dp, description_count dc ' ||
            'WHERE dc.cnt > 0 AND dp.seq_no = 1 + mod(g.row_no - 1, dc.cnt)' ||
            '))'
        ELSE '' END,

        -- units
        CASE WHEN v_has_units THEN
            '|| jsonb_build_object(' ||
            '''units'', (' ||
            'SELECT up.units FROM units_pool up, units_count uc ' ||
            'WHERE uc.cnt > 0 AND up.seq_no = 1 + mod(g.row_no - 1, uc.cnt)' ||
            '))'
        ELSE '' END
    );

    RETURN QUERY EXECUTE v_sql;

END;
$$;