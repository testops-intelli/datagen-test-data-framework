-- =========================================================
-- DATAGEN QUERY BOOK — ALL DEMO TABLES
-- (companies, securities, transactions)
--
-- Run in ONE session/connection per table section -- temp
-- tables from the materializer procs only live within the
-- session that created them, so don't split a table's block
-- across separate query tabs/connections.
--
-- Same structure repeated for every table:
--   0. Raw table
--   1. Mode 1 (JSON, materialized with placeholders,
--      materialized without placeholders)
--   2. Mode 2 (distinct-tuple count, multiplier x1/x2/x10,
--      materialized)
--   3. Mode 3 (registry entry, candidates table, multiplier
--      x1/x2/x10, materialized)
-- =========================================================


-- =========================================================
-- 0. ENVIRONMENT CHECK (once, covers all tables)
-- =========================================================

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('public', 'datagen')
ORDER BY table_schema, table_name;


-- #########################################################
-- ## TABLE: public.companies
-- #########################################################

-- 0. Raw table
SELECT * FROM public.companies ORDER BY company_id;

-- 1. Mode 1
SELECT * FROM datagen.mode_1('public', 'companies', true);

CALL datagen.materialize_mode_1_with_placeholders('public', 'companies');
SELECT * FROM datagen_mode_1_with_placeholders;

CALL datagen.materialize_mode_1_without_placeholders('public', 'companies');
SELECT * FROM datagen_mode_1_without_placeholders;

-- 2. Mode 2
SELECT COUNT(DISTINCT company_code) FROM public.companies;

SELECT * FROM datagen.mode_2('public', 'companies', 1);
SELECT * FROM datagen.mode_2('public', 'companies', 2);
SELECT * FROM datagen.mode_2('public', 'companies', 10);  -- caps at 3 distinct -> 12 rows

CALL datagen.materialize_mode_2('public', 'companies', 2);
SELECT * FROM datagen_mode_2_output;

-- 3. Mode 3
SELECT * FROM datagen.mode_3_resolution_map
WHERE target_schema_name = 'public' AND target_table_name = 'companies';

SELECT * FROM datagen.companies_candidates ORDER BY company_code;

SELECT * FROM datagen.mode_3('public', 'companies', 1);
SELECT * FROM datagen.mode_3('public', 'companies', 2);
SELECT * FROM datagen.mode_3('public', 'companies', 10);  -- caps at 5 candidates -> 20 rows

CALL datagen.materialize_mode_3('public', 'companies', 2);
SELECT * FROM datagen_mode_3_output;


-- #########################################################
-- ## TABLE: public.securities
-- #########################################################

-- 0. Raw table
SELECT * FROM public.securities ORDER BY security_id;

-- 1. Mode 1
SELECT * FROM datagen.mode_1('public', 'securities', true);

CALL datagen.materialize_mode_1_with_placeholders('public', 'securities');
SELECT * FROM datagen_mode_1_with_placeholders;

CALL datagen.materialize_mode_1_without_placeholders('public', 'securities');
SELECT * FROM datagen_mode_1_without_placeholders;

-- 2. Mode 2
SELECT COUNT(DISTINCT (security_code, currency_id)) FROM public.securities;

SELECT * FROM datagen.mode_2('public', 'securities', 1);
SELECT * FROM datagen.mode_2('public', 'securities', 2);
SELECT * FROM datagen.mode_2('public', 'securities', 10);  -- caps at 4 distinct -> 8 rows

CALL datagen.materialize_mode_2('public', 'securities', 2);
SELECT * FROM datagen_mode_2_output;

-- 3. Mode 3
SELECT * FROM datagen.mode_3_resolution_map
WHERE target_schema_name = 'public' AND target_table_name = 'securities';

SELECT * FROM datagen.securities_candidates ORDER BY security_code, currency_id;

SELECT * FROM datagen.mode_3('public', 'securities', 1);
SELECT * FROM datagen.mode_3('public', 'securities', 2);
SELECT * FROM datagen.mode_3('public', 'securities', 10);  -- caps at 5 candidates -> 10 rows

CALL datagen.materialize_mode_3('public', 'securities', 2);
SELECT * FROM datagen_mode_3_output;


-- #########################################################
-- ## TABLE: public.transactions
-- #########################################################

-- 0. Raw table
SELECT * FROM public.transactions ORDER BY transaction_id;

-- 1. Mode 1
SELECT * FROM datagen.mode_1('public', 'transactions', true);

CALL datagen.materialize_mode_1_with_placeholders('public', 'transactions');
SELECT * FROM datagen_mode_1_with_placeholders;

CALL datagen.materialize_mode_1_without_placeholders('public', 'transactions');
SELECT * FROM datagen_mode_1_without_placeholders;

-- 2. Mode 2
SELECT COUNT(DISTINCT (company_id, security_id, currency_id,
                        trade_date, units, broker_code, description))
FROM public.transactions;

SELECT * FROM datagen.mode_2('public', 'transactions', 1);
SELECT * FROM datagen.mode_2('public', 'transactions', 2);
SELECT * FROM datagen.mode_2('public', 'transactions', 10);  -- caps at 6 distinct -> 24 rows

CALL datagen.materialize_mode_2('public', 'transactions', 2);
SELECT * FROM datagen_mode_2_output;

-- 3. Mode 3
SELECT * FROM datagen.mode_3_resolution_map
WHERE target_schema_name = 'public' AND target_table_name = 'transactions';

SELECT * FROM datagen.transactions_candidates ORDER BY
    company_id, security_id, currency_id, trade_date, units, broker_code, description;

SELECT * FROM datagen.mode_3('public', 'transactions', 1);
SELECT * FROM datagen.mode_3('public', 'transactions', 2);
SELECT * FROM datagen.mode_3('public', 'transactions', 10);  -- caps at 5 candidates -> 20 rows

CALL datagen.materialize_mode_3('public', 'transactions', 2);
SELECT * FROM datagen_mode_3_output;


-- =========================================================
-- 4. RESET (start clean for a fresh run)
-- =========================================================

-- Full teardown; re-run via `python reset_all.py` / `run_all.py`,
-- or execute sql/00_reset_all.sql directly.
