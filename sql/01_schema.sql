-- =========================================================
-- 01_schema.sql
-- Create core tables DataGen v1 demo
-- =========================================================

-- defensive cleanup (in case reset not run)
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.securities CASCADE;
DROP TABLE IF EXISTS public.companies CASCADE;

CREATE TABLE public.companies (
    company_id       SERIAL PRIMARY KEY,
    company_code     TEXT NOT NULL UNIQUE,
    company_status   TEXT NOT NULL CHECK (company_status IN ('Active', 'Inactive')),
    is_active        BOOLEAN NOT NULL
);

CREATE TABLE public.securities (
    security_id      SERIAL PRIMARY KEY,
    security_code    TEXT NOT NULL UNIQUE,
    currency_id      INT NOT NULL,
    security_status  TEXT NOT NULL CHECK (security_status IN ('Active', 'Inactive'))
);

CREATE TABLE public.transactions (
    transaction_id   SERIAL PRIMARY KEY,

    company_id       INT NOT NULL,
    security_id      INT NOT NULL,
    currency_id      INT NOT NULL,

    trade_date       DATE NOT NULL,
    units            INT NOT NULL,

    status           TEXT NOT NULL CHECK (status IN ('Active', 'Inactive')),
    is_locked        BOOLEAN NOT NULL,

    broker_code      TEXT NULL,
    description      TEXT NULL,

    CONSTRAINT fk_transactions_company
        FOREIGN KEY (company_id)
        REFERENCES public.companies(company_id),

    CONSTRAINT fk_transactions_security
        FOREIGN KEY (security_id)
        REFERENCES public.securities(security_id)
);

CREATE INDEX idx_transactions_company ON public.transactions(company_id);
CREATE INDEX idx_transactions_security ON public.transactions(security_id);
CREATE INDEX idx_transactions_trade_date ON public.transactions(trade_date);














