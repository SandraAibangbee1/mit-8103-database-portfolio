-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_01_Preflight.sql
-- Description:  READ-ONLY preflight checks for KoraPay Wallet before any
--               Portfolio 3 test records or demonstrations are created.
--
-- WHAT THIS SCRIPT DOES:
--   Reports the database environment, current table sizes, the
--   SYSTEM_CLEARING wallet, any existing Portfolio 3 records, user-defined
--   functions and triggers, and any wallet whose cached balance does not
--   match its ledger.
--
-- WHAT THIS SCRIPT DOES NOT DO:
--   It contains SELECT statements only. It does not insert, update or delete
--   data, and it does not create or alter any object.
--
-- PORTFOLIO 3 NAMING PREFIXES (proposed, checked in Check 4):
--   customers.email          p3.customer.NNN@example.invalid
--   customers.phone_number   P3-TEL-NNNNNN
--   wallets.wallet_number    P3W0000001 ...
--   transactions.reference   P3-DEP-..., P3-TRF-..., P3-FAIL-..., P3-CONC-...
--
-- HOW TO RUN (pgAdmin Query Tool, connected to korapay_wallet):
--   Highlight one check at a time and execute it (F5). pgAdmin shows only
--   the last result set when the whole script is run at once.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- CHECK 1: Database environment
-- Current database, connected user, PostgreSQL version and the isolation
-- level of the current transaction (expected default: read committed).
-- ----------------------------------------------------------------------------
SELECT
    current_database()                            AS database_name,
    current_user                                  AS connected_user,
    current_setting('server_version')             AS server_version,
    version()                                     AS version_detail,
    current_setting('transaction_isolation')      AS transaction_isolation,
    current_setting('default_transaction_isolation') AS default_transaction_isolation;


-- ----------------------------------------------------------------------------
-- CHECK 2: Row counts for the four core tables
-- Expected after Portfolio 2: 5,003 wallets, 105,001 transactions and
-- 210,000 ledger entries. Record these values as the Portfolio 3 baseline.
-- ----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM customers)      AS customers,
    (SELECT COUNT(*) FROM wallets)        AS wallets,
    (SELECT COUNT(*) FROM transactions)   AS transactions,
    (SELECT COUNT(*) FROM ledger_entries) AS ledger_entries;


-- ----------------------------------------------------------------------------
-- CHECK 3: SYSTEM_CLEARING wallet
-- Exactly one row is expected (enforced by uq_single_system_clearing_wallet).
-- Its balance may be negative; Portfolio 3 funding deposits will debit it.
-- ----------------------------------------------------------------------------
SELECT
    w.wallet_id,
    w.wallet_number,
    w.wallet_type,
    w.currency,
    w.status,
    w.balance,
    w.created_at,
    w.updated_at
FROM wallets AS w
WHERE w.wallet_type = 'SYSTEM_CLEARING';


-- ----------------------------------------------------------------------------
-- CHECK 4: Existing Portfolio 3 records
-- Lists any customers, wallets or transactions that already use the
-- proposed P3 prefixes. Zero rows means the P3 setup has not been run yet.
-- ----------------------------------------------------------------------------
SELECT
    'customer'        AS record_type,
    c.customer_id     AS record_id,
    c.email           AS identifier,
    c.phone_number    AS detail,
    c.created_at
FROM customers AS c
WHERE c.email LIKE 'p3.customer.%@example.invalid'
   OR c.phone_number LIKE 'P3-TEL-%'

UNION ALL

SELECT
    'wallet',
    w.wallet_id,
    w.wallet_number,
    w.status || ' / balance ' || w.balance::TEXT,
    w.created_at
FROM wallets AS w
WHERE w.wallet_number LIKE 'P3W%'

UNION ALL

SELECT
    'transaction',
    t.transaction_id,
    t.reference,
    t.transaction_type || ' / ' || t.status || ' / ' || t.amount::TEXT,
    t.created_at
FROM transactions AS t
WHERE t.reference LIKE 'P3-%'

ORDER BY record_type, record_id;


-- ----------------------------------------------------------------------------
-- CHECK 5a: User-defined functions and procedures in the public schema
-- Excludes functions installed by extensions. Zero rows is expected:
-- no posting routine has been created in Portfolios 1 or 2.
-- ----------------------------------------------------------------------------
SELECT
    p.oid::REGPROCEDURE                           AS signature,
    CASE p.prokind
        WHEN 'f' THEN 'function'
        WHEN 'p' THEN 'procedure'
        WHEN 'a' THEN 'aggregate'
        WHEN 'w' THEN 'window'
    END                                           AS kind,
    l.lanname                                     AS language,
    pg_get_function_result(p.oid)                 AS returns,
    p.prosecdef                                   AS security_definer
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
JOIN pg_language  AS l ON l.oid = p.prolang
WHERE n.nspname = 'public'
  AND NOT EXISTS (
        SELECT 1
        FROM pg_depend AS d
        WHERE d.classid = 'pg_proc'::REGCLASS
          AND d.objid   = p.oid
          AND d.deptype = 'e'
      )
ORDER BY p.oid::REGPROCEDURE::TEXT;


-- ----------------------------------------------------------------------------
-- CHECK 5b: Non-internal triggers on public tables
-- Internal triggers (e.g. those PostgreSQL uses for foreign keys) are
-- excluded. Zero rows is expected.
-- ----------------------------------------------------------------------------
SELECT
    c.relname                                     AS table_name,
    tg.tgname                                     AS trigger_name,
    tg.tgfoid::REGPROC                            AS trigger_function,
    CASE tg.tgenabled
        WHEN 'O' THEN 'enabled'
        WHEN 'D' THEN 'disabled'
        WHEN 'R' THEN 'replica only'
        WHEN 'A' THEN 'always'
    END                                           AS enabled_state,
    pg_get_triggerdef(tg.oid)                     AS trigger_definition
FROM pg_trigger AS tg
JOIN pg_class     AS c ON c.oid = tg.tgrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND NOT tg.tgisinternal
ORDER BY table_name, trigger_name;


-- ----------------------------------------------------------------------------
-- CHECK 6: Wallet balance reconciliation (mismatches only)
-- Compares each cached wallets.balance with its signed ledger total:
-- CREDIT adds to the balance (money in), DEBIT subtracts (money out).
-- The LEFT JOIN keeps wallets with no ledger entries (ledger total 0.00),
-- so a non-zero balance without ledger history is also reported.
-- Zero rows means every wallet, including SYSTEM_CLEARING, reconciles.
-- ----------------------------------------------------------------------------
SELECT
    w.wallet_id,
    w.wallet_number,
    w.wallet_type,
    w.balance                                     AS cached_balance,
    COALESCE(lm.ledger_total, 0.00)               AS ledger_total,
    COALESCE(lm.entry_count, 0)                   AS ledger_entry_count,
    w.balance - COALESCE(lm.ledger_total, 0.00)   AS discrepancy
FROM wallets AS w
LEFT JOIN (
    SELECT
        le.wallet_id,
        SUM(CASE le.entry_type
                WHEN 'CREDIT' THEN  le.amount
                WHEN 'DEBIT'  THEN -le.amount
            END)                                  AS ledger_total,
        COUNT(*)                                  AS entry_count
    FROM ledger_entries AS le
    GROUP BY le.wallet_id
) AS lm
    ON lm.wallet_id = w.wallet_id
WHERE w.balance <> COALESCE(lm.ledger_total, 0.00)
ORDER BY w.wallet_id;
