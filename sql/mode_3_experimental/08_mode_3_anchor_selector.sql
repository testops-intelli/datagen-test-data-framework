-- =========================================================
-- 08_mode_3_anchor_selector.sql
-- DATAGEN MODE 3 - ANCHOR SELECTOR
--
-- Purpose:
--   Select a deterministic subset of anchors from the feasible
--   universe using a safe spread heuristic.
--
-- Current scope:
--   - v1 supports only public.transactions
--
-- Dependencies:
--   - 06_mode_3_setup.sql
--   - 07_mode_3_anchor_universe.sql
--
-- Input:
--   p_expand_factor >= 1
-- =========================================================

-- Note:
--   v1 selector derives anchors directly from setup tables.
--   Future versions may consume datagen.mode_3_anchor_universe(...)
--   as the canonical source.

DROP FUNCTION IF EXISTS datagen.mode_3_select_anchors(text, text, integer);

CREATE OR REPLACE FUNCTION datagen.mode_3_select_anchors(
    p_schema_name   text,
    p_table_name    text,
    p_expand_factor integer DEFAULT 2
)
RETURNS TABLE
(
    anchor_no   bigint,
    company_id  int,
    trade_date  date,
    security_id int,
    currency_id int
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_cd_count  bigint;
    v_sec_count bigint;
BEGIN
    IF p_expand_factor IS NULL OR p_expand_factor < 1 THEN
        RAISE EXCEPTION 'p_expand_factor must be >= 1';
    END IF;

    IF lower(p_schema_name) <> 'public' OR lower(p_table_name) <> 'transactions' THEN
        RAISE EXCEPTION
            'mode_3_select_anchors currently supports only public.transactions';
    END IF;

    -- -----------------------------------------------------
    -- validate required setup/helper objects exist
    -- -----------------------------------------------------
    IF to_regclass('public.global_company_dates') IS NULL THEN
        RAISE EXCEPTION 'Required table public.global_company_dates does not exist. Run 06_mode_3_setup.sql first.';
    END IF;

    IF to_regclass('public.global_securities') IS NULL THEN
        RAISE EXCEPTION 'Required table public.global_securities does not exist. Run 06_mode_3_setup.sql first.';
    END IF;

    IF to_regclass('datagen.mode_3_tuple_sources') IS NULL THEN
        RAISE EXCEPTION 'Required table datagen.mode_3_tuple_sources does not exist. Run 06_mode_3_setup.sql first.';
    END IF;

    IF to_regprocedure('datagen.mode_3_anchor_universe(text, text)') IS NULL THEN
        RAISE EXCEPTION 'Required function datagen.mode_3_anchor_universe(text, text) does not exist. Run 07_mode_3_anchor_universe.sql first.';
    END IF;

    -- -----------------------------------------------------
    -- validate source sets are non-empty
    -- -----------------------------------------------------
    SELECT COUNT(*)::bigint INTO v_cd_count
    FROM public.global_company_dates;

    SELECT COUNT(*)::bigint INTO v_sec_count
    FROM public.global_securities;

    IF v_cd_count = 0 THEN
        RAISE EXCEPTION 'public.global_company_dates is empty. Mode 3 setup is incomplete.';
    END IF;

    IF v_sec_count = 0 THEN
        RAISE EXCEPTION 'public.global_securities is empty. Mode 3 setup is incomplete.';
    END IF;

    RETURN QUERY
    WITH company_dates AS
    (
        SELECT
            row_number() OVER (
                ORDER BY gcd.company_id, gcd.trade_date
            )::bigint AS seq_no,
            gcd.company_id,
            gcd.trade_date
        FROM public.global_company_dates gcd
    ),
    securities AS
    (
        SELECT
            row_number() OVER (
                ORDER BY gs.security_id, gs.currency_id
            )::bigint AS seq_no,
            gs.security_id,
            gs.currency_id
        FROM public.global_securities gs
    ),
    requested AS
    (
        SELECT generate_series(1, p_expand_factor)::bigint AS anchor_no
    )
    SELECT
        r.anchor_no,
        cd.company_id,
        cd.trade_date,
        s.security_id,
        s.currency_id
    FROM requested r
    JOIN company_dates cd
      ON cd.seq_no = 1 + mod(r.anchor_no - 1, v_cd_count)
    JOIN securities s
      ON s.seq_no = 1 + mod(r.anchor_no - 1, v_sec_count)
    ORDER BY r.anchor_no;

END;
$$;

-- =========================================================
-- OPTIONAL SANITY CHECKS
-- =========================================================

-- preview selected anchors
-- SELECT *
-- FROM datagen.mode_3_select_anchors('public', 'transactions', 10);

-- diversity profile of selected anchors
-- SELECT
--     COUNT(*) AS selected_count,
--     COUNT(DISTINCT company_id)  AS distinct_company_id,
--     COUNT(DISTINCT trade_date)  AS distinct_trade_date,
--     COUNT(DISTINCT security_id) AS distinct_security_id,
--     COUNT(DISTINCT currency_id) AS distinct_currency_id
-- FROM datagen.mode_3_select_anchors('public', 'transactions', 10);

-- inspect ordering quality
-- SELECT *
-- FROM datagen.mode_3_select_anchors('public', 'transactions', 20);


