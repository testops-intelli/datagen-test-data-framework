-- =========================================================
-- 06_mode_3_setup.sql
-- DATAGEN MODE 3 - SETUP
--
-- Purpose:
--   Create and seed the feasible-universe source tables and
--   tuple-source metadata used by Mode 3.
--
-- Includes:
--   1) public.global_companies
--   2) public.global_securities
--   3) public.global_company_dates
--   4) datagen.mode_3_tuple_sources
--
-- Dependencies:
--   - 01_schema.sql
--   - 02_seed_demo_data.sql
--   - 03_core_helpers.sql
--
-- Notes:
--   - v1 setup supports Mode 3 generation for public.transactions
--   - setup objects are permanent demo/support objects, not temp outputs
--   - idempotent-safe for repeated demo rebuilds
-- =========================================================

CREATE SCHEMA IF NOT EXISTS datagen;

-- =========================================================
-- DROP / RESET
-- =========================================================
DROP TABLE IF EXISTS public.global_company_dates CASCADE;
DROP TABLE IF EXISTS public.global_securities CASCADE;
DROP TABLE IF EXISTS public.global_companies CASCADE;
DROP TABLE IF EXISTS datagen.mode_3_tuple_sources CASCADE;

-- =========================================================
-- 1) GLOBAL_COMPANIES
-- =========================================================
CREATE TABLE IF NOT EXISTS public.global_companies (
    company_id   INT PRIMARY KEY,
    company_code TEXT NOT NULL UNIQUE
);

INSERT INTO public.global_companies (company_id, company_code)
VALUES
(1,  'FUND_A'),
(2,  'FUND_B'),
(3,  'FUND_C'),
(4,  'FUND_D'),
(5,  'FUND_E'),
(6,  'FUND_F'),
(7,  'FUND_G'),
(8,  'FUND_H'),
(9,  'FUND_I'),
(10, 'FUND_J'),
(11, 'FUND_K'),
(12, 'FUND_L'),
(13, 'FUND_M'),
(14, 'FUND_N'),
(15, 'FUND_O'),
(16, 'FUND_P'),
(17, 'FUND_Q'),
(18, 'FUND_R'),
(19, 'FUND_S'),
(20, 'FUND_T')
ON CONFLICT (company_id) DO NOTHING;

-- =========================================================
-- 2) GLOBAL_SECURITIES
--
-- Strict tuple:
--   security_id, security_code, currency_id
-- =========================================================
CREATE TABLE IF NOT EXISTS public.global_securities (
    security_id   INT PRIMARY KEY,
    security_code TEXT NOT NULL UNIQUE,
    currency_id   INT NOT NULL
);

INSERT INTO public.global_securities (security_id, security_code, currency_id)
VALUES
-- existing local demo securities
(1,  'SEC_AU_1',  36),
(2,  'SEC_US_1',  840),
(3,  'SEC_EU_1',  978),
(4,  'SEC_AU_2',  36),

-- broader feasible universe
(5,  'SEC_US_2',  840),
(6,  'SEC_EU_2',  978),
(7,  'SEC_AU_3',  36),
(8,  'SEC_US_3',  840),
(9,  'SEC_EU_3',  978),
(10, 'SEC_AU_4',  36),
(11, 'SEC_US_4',  840),
(12, 'SEC_EU_4',  978),
(13, 'SEC_AU_5',  36),
(14, 'SEC_US_5',  840),
(15, 'SEC_EU_5',  978),
(16, 'SEC_AU_6',  36),
(17, 'SEC_US_6',  840),
(18, 'SEC_EU_6',  978),
(19, 'SEC_AU_7',  36),
(20, 'SEC_US_7',  840),
(21, 'SEC_EU_7',  978)
ON CONFLICT (security_id) DO NOTHING;

-- =========================================================
-- 3) GLOBAL_COMPANY_DATES
--
-- Strict tuple:
--   company_id, trade_date
--
-- Rules:
--   - includes historical dates from local transactions
--   - adds realistic spread across 2025
-- =========================================================
CREATE TABLE IF NOT EXISTS public.global_company_dates (
    company_id  INT  NOT NULL,
    trade_date  DATE NOT NULL,
    PRIMARY KEY (company_id, trade_date),
    CONSTRAINT fk_global_company_dates_company
        FOREIGN KEY (company_id)
        REFERENCES public.global_companies(company_id)
);

INSERT INTO public.global_company_dates (company_id, trade_date)
VALUES
-- company 1 (includes original transaction dates)
(1, DATE '2025-01-01'),
(1, DATE '2025-01-10'),
(1, DATE '2025-01-25'),
(1, DATE '2025-03-31'),
(1, DATE '2025-06-30'),
(1, DATE '2025-09-30'),
(1, DATE '2025-12-31'),

-- company 2 (includes original transaction dates)
(2, DATE '2025-01-05'),
(2, DATE '2025-01-20'),
(2, DATE '2025-02-28'),
(2, DATE '2025-05-31'),
(2, DATE '2025-08-31'),
(2, DATE '2025-11-30'),

-- company 3 (includes original transaction date)
(3, DATE '2025-01-15'),
(3, DATE '2025-04-15'),
(3, DATE '2025-07-15'),
(3, DATE '2025-10-15'),
(3, DATE '2025-12-15'),

-- company 4
(4, DATE '2025-01-07'),
(4, DATE '2025-03-07'),
(4, DATE '2025-05-07'),
(4, DATE '2025-07-07'),
(4, DATE '2025-09-07'),
(4, DATE '2025-11-07'),

-- company 5
(5, DATE '2025-01-05'),
(5, DATE '2025-05-01'),
(5, DATE '2025-09-01'),
(5, DATE '2025-12-01'),

-- company 6
(6, DATE '2025-02-01'),
(6, DATE '2025-04-01'),
(6, DATE '2025-06-01'),
(6, DATE '2025-08-01'),
(6, DATE '2025-10-01'),
(6, DATE '2025-12-01'),

-- company 7
(7, DATE '2025-01-12'),
(7, DATE '2025-04-12'),
(7, DATE '2025-07-12'),
(7, DATE '2025-10-12'),

-- company 8
(8, DATE '2025-02-14'),
(8, DATE '2025-06-14'),
(8, DATE '2025-10-14'),

-- company 9
(9, DATE '2025-01-03'),
(9, DATE '2025-03-03'),
(9, DATE '2025-05-03'),
(9, DATE '2025-07-03'),
(9, DATE '2025-09-03'),
(9, DATE '2025-11-03'),

-- company 10
(10, DATE '2025-01-02'),
(10, DATE '2025-02-02'),
(10, DATE '2025-06-02'),
(10, DATE '2025-10-02'),

-- company 11
(11, DATE '2025-01-18'),
(11, DATE '2025-05-18'),
(11, DATE '2025-09-18'),

-- company 12
(12, DATE '2025-02-20'),
(12, DATE '2025-06-20'),
(12, DATE '2025-10-20'),

-- company 13
(13, DATE '2025-01-08'),
(13, DATE '2025-04-08'),
(13, DATE '2025-08-08'),
(13, DATE '2025-12-08'),

-- company 14
(14, DATE '2025-03-11'),
(14, DATE '2025-07-11'),
(14, DATE '2025-11-11'),

-- company 15
(15, DATE '2025-01-22'),
(15, DATE '2025-04-22'),
(15, DATE '2025-07-22'),
(15, DATE '2025-10-22'),

-- company 16
(16, DATE '2025-02-09'),
(16, DATE '2025-05-09'),
(16, DATE '2025-08-09'),
(16, DATE '2025-11-09'),

-- company 17
(17, DATE '2025-01-27'),
(17, DATE '2025-03-27'),
(17, DATE '2025-06-27'),
(17, DATE '2025-09-27'),
(17, DATE '2025-12-27'),

-- company 18
(18, DATE '2025-02-17'),
(18, DATE '2025-05-17'),
(18, DATE '2025-08-17'),
(18, DATE '2025-11-17'),

-- company 19
(19, DATE '2025-01-30'),
(19, DATE '2025-04-30'),
(19, DATE '2025-07-30'),
(19, DATE '2025-10-30'),

-- company 20
(20, DATE '2025-02-25'),
(20, DATE '2025-06-25'),
(20, DATE '2025-10-25')
ON CONFLICT (company_id, trade_date) DO NOTHING;

-- =========================================================
-- 4) MODE 3 TUPLE-SOURCE METADATA
--
-- target_columns_json:
--   placeholder business/FK candidate columns on target table
--
-- source_columns_json:
--   corresponding columns on source table
--
-- tuple_source_type:
--   currently informative only
--   can later drive helper logic
--
-- is_strict_tuple:
--   strict tuple integrity required
-- =========================================================
CREATE TABLE IF NOT EXISTS datagen.mode_3_tuple_sources (
    target_schema_name   TEXT    NOT NULL,
    target_table_name    TEXT    NOT NULL,
    tuple_group_name     TEXT    NOT NULL,
    target_columns_json  JSONB   NOT NULL,
    source_schema_name   TEXT    NOT NULL,
    source_table_name    TEXT    NOT NULL,
    source_columns_json  JSONB   NOT NULL,
    tuple_source_type    TEXT    NOT NULL,
    is_strict_tuple      BOOLEAN NOT NULL DEFAULT TRUE,
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    notes                TEXT    NULL,
    PRIMARY KEY (target_schema_name, target_table_name, tuple_group_name)
);

INSERT INTO datagen.mode_3_tuple_sources
(
    target_schema_name,
    target_table_name,
    tuple_group_name,
    target_columns_json,
    source_schema_name,
    source_table_name,
    source_columns_json,
    tuple_source_type,
    is_strict_tuple,
    is_active,
    notes
)
VALUES
-- companies: company_id comes from feasible global company universe
(
    'public',
    'companies',
    'company_key_tuple',
    '["company_id"]'::jsonb,
    'public',
    'global_companies',
    '["company_id"]'::jsonb,
    'feasible_lookup',
    TRUE,
    TRUE,
    'Mode_3 feasible source for company_id in companies'
),

-- securities: security_id and currency_id must travel together from global_securities
(
    'public',
    'securities',
    'security_currency_tuple',
    '["security_id","currency_id"]'::jsonb,
    'public',
    'global_securities',
    '["security_id","currency_id"]'::jsonb,
    'feasible_lookup',
    TRUE,
    TRUE,
    'Strict feasible tuple for securities'
),

-- transactions: company_id and trade_date come from global_company_dates
(
    'public',
    'transactions',
    'company_trade_date_tuple',
    '["company_id","trade_date"]'::jsonb,
    'public',
    'global_company_dates',
    '["company_id","trade_date"]'::jsonb,
    'feasible_lookup',
    TRUE,
    TRUE,
    'Strict feasible tuple for company/date anchors'
),

-- transactions: security_id and currency_id come from global_securities
(
    'public',
    'transactions',
    'security_currency_tuple',
    '["security_id","currency_id"]'::jsonb,
    'public',
    'global_securities',
    '["security_id","currency_id"]'::jsonb,
    'feasible_lookup',
    TRUE,
    TRUE,
    'Strict feasible tuple for security/currency anchors'
)
ON CONFLICT (target_schema_name, target_table_name, tuple_group_name) DO NOTHING;

-- =========================================================
-- SUPPORTING INDEXES
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_global_company_dates_company
ON public.global_company_dates(company_id);

CREATE INDEX IF NOT EXISTS idx_global_securities_currency
ON public.global_securities(currency_id);

CREATE INDEX IF NOT EXISTS idx_tuple_sources_target
ON datagen.mode_3_tuple_sources(target_schema_name, target_table_name);

-- =========================================================
-- SANITY ASSERTION
-- =========================================================
DO $$
DECLARE
    v_cnt int;
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM datagen.mode_3_tuple_sources;

    IF v_cnt < 4 THEN
        RAISE EXCEPTION 'Mode 3 setup incomplete: expected at least 4 tuple-source rows, got %', v_cnt;
    END IF;
END;
$$;

-- =========================================================
-- OPTIONAL SANITY CHECKS
-- =========================================================
-- SELECT * FROM public.global_companies ORDER BY company_id;
-- SELECT * FROM public.global_securities ORDER BY security_id;
-- SELECT * FROM public.global_company_dates ORDER BY company_id, trade_date;
-- SELECT * FROM datagen.mode_3_tuple_sources ORDER BY target_table_name, tuple_group_name;