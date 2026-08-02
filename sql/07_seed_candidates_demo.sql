-- =========================================================
-- 07_seed_candidates_demo.sql
-- DEMO CANDIDATES TABLE + MODE 3 REGISTRY SEED
--
-- Purpose:
--   Populate one example user-supplied candidates table for
--   the demo `public.transactions` table, and register it in
--   datagen.mode_3_resolution_map so the end-to-end demo can
--   run out of the box.
--
-- Schema placement:
--   Candidates tables live under the `datagen` schema, not
--   `public` -- they're curated data supporting the engine,
--   not business data, so they stay out of the schema where
--   your actual tables live. `datagen` already holds engine
--   metadata (mode_3_resolution_map); candidates tables sit
--   alongside it rather than mixed into `public`.
--
-- Scope note:
--   Curating which values (and which combinations) belong in
--   a candidates table is the caller's responsibility in real
--   usage (see notes in 06_mode_3.sql). This file exists
--   purely so the packaged demo has something to resolve
--   against; it is not part of the generic engine.
--
-- Dependencies:
--   - 01_schema.sql
--   - 02_seed_demo_data.sql
--   - 06_mode_3.sql   (requires datagen.mode_3_resolution_map)
-- =========================================================

-- =========================================================
-- DROP / RESET
-- =========================================================
DROP TABLE IF EXISTS datagen.transactions_candidates CASCADE;

-- =========================================================
-- CANDIDATES TABLE FOR transactions
--
-- One row = one legal combination of every currently-
-- unresolved column on public.transactions (everything Mode 1
-- placeholds: company_id, security_id, currency_id, trade_date,
-- units, broker_code, description). The user is asserting
-- these column values are valid together as a tuple.
--
-- Lives under `datagen`, but its FKs still point at the real
-- business tables in `public` -- cross-schema FKs work
-- normally in Postgres, and this keeps referential integrity
-- against the actual companies/securities data.
-- =========================================================
CREATE TABLE datagen.transactions_candidates (
    company_id   INT  NOT NULL,
    security_id  INT  NOT NULL,
    currency_id  INT  NOT NULL,
    trade_date   DATE NOT NULL,
    units        INT  NOT NULL,
    broker_code  TEXT NOT NULL,
    description  TEXT NOT NULL,
    CONSTRAINT fk_transactions_candidates_company
        FOREIGN KEY (company_id)
        REFERENCES public.companies(company_id),
    CONSTRAINT fk_transactions_candidates_security
        FOREIGN KEY (security_id)
        REFERENCES public.securities(security_id)
);

INSERT INTO datagen.transactions_candidates
(company_id, security_id, currency_id, trade_date, units, broker_code, description)
VALUES
(1, 1, 36,  DATE '2025-01-01', 100, 'BRK_A', 'Curated candidate #1 for FUND_A'),
(2, 2, 840, DATE '2025-01-05', 250, 'BRK_B', 'Curated candidate #2 for FUND_B'),
(3, 3, 978, DATE '2025-01-15', 400, 'BRK_C', 'Curated candidate #3 for FUND_C'),
(1, 4, 36,  DATE '2025-01-10', 175, 'BRK_A', 'Curated candidate #4 for FUND_A'),
(2, 1, 36,  DATE '2025-01-20', 320, 'BRK_D', 'Curated candidate #5 for FUND_B');

-- =========================================================
-- MODE 3 REGISTRY ENTRY
-- =========================================================
INSERT INTO datagen.mode_3_resolution_map
(
    target_schema_name,
    target_table_name,
    placeholder_columns_json,
    candidates_schema_name,
    candidates_table_name,
    is_active,
    notes
)
VALUES
(
    'public',
    'transactions',
    '["company_id","security_id","currency_id","trade_date","units","broker_code","description"]'::jsonb,
    'datagen',
    'transactions_candidates',
    TRUE,
    'Demo candidates for all Mode 1 placeholder columns on transactions'
)
ON CONFLICT (target_schema_name, target_table_name) DO NOTHING;

-- =========================================================
-- OPTIONAL SANITY CHECKS
-- =========================================================
-- SELECT * FROM datagen.transactions_candidates ORDER BY company_id, security_id, currency_id, trade_date, units, broker_code, description;
-- SELECT * FROM datagen.mode_3_resolution_map;
