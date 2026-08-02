-- =========================================================
-- 02_seed_demo_data.sql
-- Minimal controlled seed data for DataGen v1 demo
-- =========================================================

-- ensure tables exist (guard for orchestration mistakes)
DO $$
BEGIN
    IF to_regclass('public.companies') IS NULL THEN
        RAISE EXCEPTION 'Run 01_schema.sql before seeding';
    END IF;
END;
$$;

-- REQUIRED for deterministic demo runs
TRUNCATE TABLE public.transactions RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.securities RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.companies RESTART IDENTITY CASCADE;

-- =========================================================
-- COMPANIES
-- =========================================================
INSERT INTO public.companies
(
    company_code,
    company_status,
    is_active
)
VALUES
('FUND_A', 'Active',   TRUE),
('FUND_B', 'Active',   TRUE),
('FUND_C', 'Inactive', FALSE);

-- Expected IDs after fresh reset:
-- FUND_A = 1
-- FUND_B = 2
-- FUND_C = 3


-- =========================================================
-- SECURITIES
-- currency_id is intentionally not FK constrained in v1
-- =========================================================
INSERT INTO public.securities
(
    security_code,
    currency_id,
    security_status
)
VALUES
('SEC_AU_1', 36, 'Active'),
('SEC_US_1', 840, 'Active'),
('SEC_EU_1', 978, 'Inactive'),
('SEC_AU_2', 36, 'Active');

-- Expected IDs after fresh reset:
-- SEC_AU_1 = 1
-- SEC_US_1 = 2
-- SEC_EU_1 = 3
-- SEC_AU_2 = 4


-- =========================================================
-- TRANSACTIONS
-- historical rows intentionally small and readable.
-- Used to demonstrate Mode 1's structural param space and Mode 2's
-- historical-tuple resolution. Mode 3 resolution for this table is
-- driven by the separate candidates table seeded in
-- 07_seed_candidates_demo.sql, not by these rows.
-- =========================================================
INSERT INTO public.transactions
(
    company_id,
    security_id,
    currency_id,
    trade_date,
    units,
    status,
    is_locked,
    broker_code,
    description
)
VALUES
-- Tuple 1
(1, 1, 36,  DATE '2025-01-01', 100, 'Active',   FALSE, 'BRK_A', 'Initial buy for FUND_A in AUD security'),

-- Tuple 2
(2, 2, 840, DATE '2025-01-05', 250, 'Active',   TRUE,  'BRK_B', 'Locked USD trade for FUND_B'),

-- Tuple 3
(1, 4, 36,  DATE '2025-01-10', 500, 'Inactive', FALSE, NULL,    'Inactive scenario for alternate AUD security'),

-- Tuple 4
(3, 3, 978, DATE '2025-01-15', 1000,'Inactive', TRUE,  'BRK_C', 'Inactive company and inactive EUR security'),

-- Tuple 5
(2, 1, 36,  DATE '2025-01-20', 750, 'Active',   FALSE, 'BRK_A', 'Cross-company holding in AUD security'),

-- Tuple 6
(1, 2, 840, DATE '2025-01-25', 300, 'Active',   FALSE, NULL,    'USD exposure for FUND_A');


-- =========================================================
-- SANITY CHECKS (optional)
-- =========================================================

-- SELECT COUNT(*) FROM public.companies;
-- SELECT COUNT(*) FROM public.securities;
-- SELECT COUNT(*) FROM public.transactions;

-- SELECT * FROM public.transactions ORDER BY transaction_id;

