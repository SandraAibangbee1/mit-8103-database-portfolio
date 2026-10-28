-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_20_FinalIntegrityChecks.sql
-- Description:  FINAL READ-ONLY INTEGRITY CHECKS after all Portfolio 3 work.
--               One SELECT returns one row per check with observed value,
--               expected value and pass = true/false. Changes nothing.
--
-- HOW TO RUN: pgAdmin Query Tool, execute the whole file (one statement),
-- after p3_18 and p3_19 have finished. Close or COMMIT/ROLLBACK every
-- experiment tab first.                                    [SCREENSHOT 1]
-- Expected: pass = true on every row. Recorded result: the P3 analysis, Section 12.3 (rows 1-5 visible in P3_54).
-- Check 11 assumes p3_19 was run and committed both references.
-- ============================================================================

WITH
ledger_totals AS (
    SELECT wallet_id,
           SUM(CASE entry_type WHEN 'CREDIT' THEN amount
                               WHEN 'DEBIT'  THEN -amount END) AS ledger_total
    FROM ledger_entries
    GROUP BY wallet_id
),
ledger_pairs AS (
    SELECT t.transaction_id,
           t.status,
           t.amount,
           COUNT(le.ledger_entry_id)                                          AS entries,
           COUNT(*) FILTER (WHERE le.entry_type = 'DEBIT'  AND le.amount = t.amount) AS good_debits,
           COUNT(*) FILTER (WHERE le.entry_type = 'CREDIT' AND le.amount = t.amount) AS good_credits
    FROM transactions AS t
    LEFT JOIN ledger_entries AS le ON le.transaction_id = t.transaction_id
    GROUP BY t.transaction_id, t.status, t.amount
),
b AS (
    SELECT * FROM p3_lab.setup_baseline
),
checks (check_no, check_name, observed, expected) AS (
    VALUES
    (1, 'Wallets whose balance differs from their ledger total',
        (SELECT COUNT(*) FROM wallets AS w
         LEFT JOIN ledger_totals AS lt ON lt.wallet_id = w.wallet_id
         WHERE w.balance <> COALESCE(lt.ledger_total, 0.00))::TEXT, '0'),
    (2, 'Customer wallets with a negative balance',
        (SELECT COUNT(*) FROM wallets
         WHERE wallet_type = 'CUSTOMER' AND balance < 0)::TEXT, '0'),
    (3, 'SUCCESSFUL transactions without exactly one matching DEBIT and CREDIT',
        (SELECT COUNT(*) FROM ledger_pairs
         WHERE status = 'SUCCESSFUL'
           AND NOT (entries = 2 AND good_debits = 1 AND good_credits = 1))::TEXT, '0'),
    (4, 'PENDING or FAILED transactions that have ledger entries',
        (SELECT COUNT(*) FROM ledger_pairs
         WHERE status IN ('PENDING', 'FAILED') AND entries > 0)::TEXT, '0'),
    (5, 'Duplicate transaction references',
        (SELECT COUNT(*) FROM (SELECT reference FROM transactions
                               GROUP BY reference HAVING COUNT(*) > 1) AS d)::TEXT, '0'),
    (6, 'Unfinished P3 transactions (reference P3%, not SUCCESSFUL)',
        (SELECT COUNT(*) FROM transactions
         WHERE reference LIKE 'P3%' AND status <> 'SUCCESSFUL')::TEXT, '0'),
    (7, 'Total of all wallet balances equals p3_13 baseline',
        ((SELECT SUM(balance) FROM wallets) = (SELECT total_wallet_balance FROM b))::TEXT, 'true'),
    (8, 'Non-lab customer wallets unchanged since p3_13 (count and total)',
        ((SELECT COUNT(*) FROM wallets
          WHERE wallet_type = 'CUSTOMER' AND wallet_number NOT LIKE 'P3LW%')
             = (SELECT existing_customer_wallet_count FROM b)
         AND (SELECT SUM(balance) FROM wallets
              WHERE wallet_type = 'CUSTOMER' AND wallet_number NOT LIKE 'P3LW%')
             = (SELECT existing_customer_wallet_balance FROM b))::TEXT, 'true'),
    (9, 'p3_lab.accounts: total 1801800.00 and no negative balance',
        ((SELECT SUM(balance) FROM p3_lab.accounts) = 1801800.00
         AND NOT EXISTS (SELECT 1 FROM p3_lab.accounts WHERE balance < 0))::TEXT, 'true'),
    (10, 'Experiment sessions (application_name P3_%) with an open transaction',
        (SELECT COUNT(*) FROM pg_stat_activity
         WHERE application_name LIKE 'P3\_%'
           AND xact_start IS NOT NULL
           AND pid <> pg_backend_pid())::TEXT, '0'),
    (11, 'p3_19 references with exactly one SUCCESSFUL transaction',
        (SELECT COUNT(*) FROM (SELECT reference FROM transactions
                               WHERE reference IN ('P3L-RETRY-COMMIT-001', 'P3L-RETRY-ROLLBACK-001')
                                 AND status = 'SUCCESSFUL'
                               GROUP BY reference HAVING COUNT(*) = 1) AS r)::TEXT, '2'),
    (12, 'Prepared (two-phase) transactions left behind',
        (SELECT COUNT(*) FROM pg_prepared_xacts)::TEXT, '0')
)
SELECT check_no,
       check_name,
       observed,
       expected,
       observed = expected AS pass
FROM checks
ORDER BY check_no;
