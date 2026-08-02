-- =========================================================
-- 00_reset_all.sql
-- FULL RESET FOR DATAGEN DEMO OBJECTS
-- =========================================================

-- -----------------------------
-- Drop temp-style / output tables first
-- -----------------------------
DROP TABLE IF EXISTS datagen_mode_3_output CASCADE;
DROP TABLE IF EXISTS datagen_mode_2_output CASCADE;
DROP TABLE IF EXISTS datagen_mode_1_with_placeholders CASCADE;
DROP TABLE IF EXISTS datagen_mode_1_without_placeholders CASCADE;

-- -----------------------------
-- Drop procedures
-- -----------------------------
DROP PROCEDURE IF EXISTS datagen.materialize_mode_3(text, text, integer);
DROP PROCEDURE IF EXISTS datagen.materialize_mode_2(text, text, integer);
DROP PROCEDURE IF EXISTS datagen.materialize_mode_1_with_placeholders(text, text);
DROP PROCEDURE IF EXISTS datagen.materialize_mode_1_without_placeholders(text, text);

-- -----------------------------
-- Drop functions
-- -----------------------------
DROP FUNCTION IF EXISTS datagen.mode_3(text, text, integer);
DROP FUNCTION IF EXISTS datagen.mode_2(text, text, integer);
DROP FUNCTION IF EXISTS datagen.mode_1(text, text, boolean);
DROP FUNCTION IF EXISTS datagen.get_check_domain(regclass, text);

-- -----------------------------
-- Drop registry / candidates tables
-- -----------------------------
DROP TABLE IF EXISTS datagen.mode_3_resolution_map CASCADE;
DROP TABLE IF EXISTS datagen.transactions_candidates CASCADE;
DROP TABLE IF EXISTS datagen.companies_candidates CASCADE;
DROP TABLE IF EXISTS datagen.securities_candidates CASCADE;

-- -----------------------------
-- Drop base demo tables
-- -----------------------------
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.securities CASCADE;
DROP TABLE IF EXISTS public.companies CASCADE;

-- -----------------------------
-- Drop datagen schema
-- -----------------------------
DROP SCHEMA IF EXISTS datagen CASCADE;

-- -----------------------------
-- Legacy cleanup (pre-v3 object names from earlier working
-- iterations of this framework -- Mode A/B naming and the
-- old multi-group Mode B registry -- safe no-ops if this is
-- a fresh environment or already current)
-- -----------------------------
DROP TABLE IF EXISTS datagen_mode_b_output CASCADE;
DROP TABLE IF EXISTS datagen_mode_a_with_placeholders CASCADE;
DROP TABLE IF EXISTS datagen_mode_a_without_placeholders CASCADE;
DROP PROCEDURE IF EXISTS datagen.materialize_mode_b(text, text, integer);
DROP PROCEDURE IF EXISTS datagen.materialize_mode_a_with_placeholders(text, text);
DROP PROCEDURE IF EXISTS datagen.materialize_mode_a_without_placeholders(text, text);
DROP FUNCTION IF EXISTS datagen.mode_b(text, text, integer);
DROP FUNCTION IF EXISTS datagen.mode_a(text, text, boolean);
DROP TABLE IF EXISTS datagen.mode_b_resolution_map CASCADE;
DROP TABLE IF EXISTS public.transactions_candidates CASCADE;
DROP TABLE IF EXISTS public.demo_candidates_company_dates CASCADE;
DROP TABLE IF EXISTS public.demo_candidates_securities CASCADE;
DROP TABLE IF EXISTS public.global_company_dates CASCADE;
DROP TABLE IF EXISTS public.global_securities CASCADE;
DROP TABLE IF EXISTS public.global_companies CASCADE;
