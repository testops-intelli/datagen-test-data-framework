-- =========================================================
-- 07_mode_3_anchor_universe.sql
-- DATAGEN MODE 3 - RAW ANCHOR UNIVERSE
--
-- Purpose:
--   Return the raw feasible anchor universe for Mode 3.
--
-- Current scope:
--   - v1 supports only public.transactions
--
-- Dependencies:
--   - 06_mode_3_setup.sql
--
-- Output:
--   company_id, trade_date, security_id, currency_id
-- =========================================================

DROP FUNCTION IF EXISTS datagen.mode_3_anchor_universe(text, text);

CREATE OR REPLACE FUNCTION datagen.mode_3_anchor_universe(
    p_schema_name text,
    p_table_name  text
)
RETURNS TABLE
(
    company_id  int,
    trade_date  date,
    security_id int,
    currency_id int
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_company_date_exists integer;
    v_security_ccy_exists integer;
BEGIN
    -- -----------------------------------------------------
    -- v1 safety gate
    -- -----------------------------------------------------
    IF lower(p_schema_name) <> 'public' OR lower(p_table_name) <> 'transactions' THEN
        RAISE EXCEPTION
            'mode_3_anchor_universe currently supports only public.transactions';
    END IF;

    -- -----------------------------------------------------
    -- validate required setup tables exist
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

    -- -----------------------------------------------------
    -- validate required tuple-source metadata exists
    -- -----------------------------------------------------
    SELECT COUNT(*)
    INTO v_company_date_exists
    FROM datagen.mode_3_tuple_sources s
    WHERE s.target_schema_name = p_schema_name
      AND s.target_table_name  = p_table_name
      AND s.tuple_group_name   = 'company_trade_date_tuple'
      AND s.is_active          = TRUE;

    IF v_company_date_exists <> 1 THEN
        RAISE EXCEPTION
            'Expected exactly 1 active tuple source for company_trade_date_tuple on %.%',
            p_schema_name, p_table_name;
    END IF;

    SELECT COUNT(*)
    INTO v_security_ccy_exists
    FROM datagen.mode_3_tuple_sources s
    WHERE s.target_schema_name = p_schema_name
      AND s.target_table_name  = p_table_name
      AND s.tuple_group_name   = 'security_currency_tuple'
      AND s.is_active          = TRUE;

    IF v_security_ccy_exists <> 1 THEN
        RAISE EXCEPTION
            'Expected exactly 1 active tuple source for security_currency_tuple on %.%',
            p_schema_name, p_table_name;
    END IF;

    -- -----------------------------------------------------
    -- raw feasible anchor universe
    -- strict tuple groups:
    --   (company_id, trade_date)   from global_company_dates
    --   (security_id, currency_id) from global_securities
    -- -----------------------------------------------------
    RETURN QUERY
    SELECT
        gcd.company_id,
        gcd.trade_date,
        gs.security_id,
        gs.currency_id
    FROM public.global_company_dates gcd
    CROSS JOIN public.global_securities gs
    ORDER BY
        gcd.company_id,
        gcd.trade_date,
        gs.security_id,
        gs.currency_id;

END;
$$;

-- =========================================================
-- OPTIONAL SANITY CHECKS
-- =========================================================

-- raw preview
-- SELECT *
-- FROM datagen.mode_3_anchor_universe('public', 'transactions')
-- LIMIT 20;

-- total universe size
-- SELECT COUNT(*) AS anchor_count
-- FROM datagen.mode_3_anchor_universe('public', 'transactions');

-- diversity profile
-- SELECT
--     COUNT(*) AS anchor_count,
--     COUNT(DISTINCT company_id)  AS distinct_company_id,
--     COUNT(DISTINCT trade_date)  AS distinct_trade_date,
--     COUNT(DISTINCT security_id) AS distinct_security_id,
--     COUNT(DISTINCT currency_id) AS distinct_currency_id
-- FROM datagen.mode_3_anchor_universe('public', 'transactions');

-- company/date spread
-- SELECT
--     company_id,
--     COUNT(*) AS anchors_for_company
-- FROM datagen.mode_3_anchor_universe('public', 'transactions')
-- GROUP BY company_id
-- ORDER BY company_id;

-- security/currency spread
-- SELECT
--     security_id,
--     currency_id,
--     COUNT(*) AS anchors_for_security
-- FROM datagen.mode_3_anchor_universe('public', 'transactions')
-- GROUP BY security_id, currency_id
-- ORDER BY security_id;

