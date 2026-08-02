-- =========================================================
-- 08_seed_candidates_companies_securities.sql
-- DEMO CANDIDATES TABLES + MODE 3 REGISTRY SEED
-- (companies, securities)
--
-- Purpose:
--   Same purpose as 07_seed_candidates_demo.sql (which covers
--   transactions), for the other two demo business tables.
--   Populates one candidates table per target table and
--   registers each in datagen.mode_3_resolution_map.
--
-- Placeholder columns per table (verified against Mode 1
-- output, not assumed from schema alone):
--   companies:  company_code                     (1 column --
--               company_status/is_active are deterministic
--               and already resolved by Mode 1)
--   securities: security_code, currency_id        (2 columns --
--               security_status is deterministic)
--
-- Schema placement: datagen, same convention as
-- transactions_candidates -- curated support data stays out
-- of `public`.
--
-- Dependencies:
--   - 01_schema.sql
--   - 06_mode_3.sql   (requires datagen.mode_3_resolution_map)
-- =========================================================

-- =========================================================
-- DROP / RESET
-- =========================================================
DROP TABLE IF EXISTS datagen.companies_candidates CASCADE;
DROP TABLE IF EXISTS datagen.securities_candidates CASCADE;

-- =========================================================
-- CANDIDATES TABLE FOR companies
-- =========================================================
CREATE TABLE datagen.companies_candidates (
    company_code TEXT NOT NULL
);

INSERT INTO datagen.companies_candidates (company_code)
VALUES
('FUND_A'),
('FUND_B'),
('FUND_C'),
('FUND_NEW_1'),
('FUND_NEW_2');

-- =========================================================
-- CANDIDATES TABLE FOR securities
-- =========================================================
CREATE TABLE datagen.securities_candidates (
    security_code TEXT NOT NULL,
    currency_id   INT  NOT NULL
);

INSERT INTO datagen.securities_candidates (security_code, currency_id)
VALUES
('SEC_AU_1', 36),
('SEC_US_1', 840),
('SEC_EU_1', 978),
('SEC_AU_NEW', 36),
('SEC_US_NEW', 840);

-- =========================================================
-- MODE 3 REGISTRY ENTRIES
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
    'companies',
    '["company_code"]'::jsonb,
    'datagen',
    'companies_candidates',
    TRUE,
    'Demo candidates for companies.company_code'
),
(
    'public',
    'securities',
    '["security_code","currency_id"]'::jsonb,
    'datagen',
    'securities_candidates',
    TRUE,
    'Demo candidates for securities.security_code / currency_id'
)
ON CONFLICT (target_schema_name, target_table_name) DO NOTHING;

-- =========================================================
-- OPTIONAL SANITY CHECKS
-- =========================================================
-- SELECT * FROM datagen.companies_candidates ORDER BY company_code;
-- SELECT * FROM datagen.securities_candidates ORDER BY security_code, currency_id;
-- SELECT * FROM datagen.mode_3_resolution_map;
