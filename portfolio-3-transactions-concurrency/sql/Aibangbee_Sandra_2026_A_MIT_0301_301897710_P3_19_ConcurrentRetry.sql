-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_19_ConcurrentRetry.sql
-- Description:  CONCURRENT IDENTICAL RETRIES with public.korapay_transfer_funds
--               (p3_09), on ledger-backed lab wallets P3LW000001 -> P3LW000002.
--   Part 1 (commit):   A calls first and COMMITS; B's identical call waits,
--                      then returns A's transaction_id. Money moves once.
--   Part 2 (rollback): A calls first and ROLLS BACK; B's identical call waits,
--                      then posts the transfer itself. Money moves once.
--   Fresh references: P3L-RETRY-COMMIT-001 and P3L-RETRY-ROLLBACK-001.
--   Amount: 1.00 each. Two transfers are committed in total.
--
-- HOW TO RUN: open this file in TWO pgAdmin Query Tool tabs (A and B).
-- Highlight ONE section at a time (F5); never the whole file.
-- "Auto rollback on error" OFF in both tabs.
--
-- EXECUTION ORDER:
--   1. A  R1   Identify A.
--   2. B  R2   Identify B.
--   3. A  R3   Pre-check: both references unused; opening balances.
--   Part 1 — first caller commits
--   4. A  R4   BEGIN; call (COMMIT reference). Expected: transaction_id N.
--   5. B  R5   BEGIN; identical call. Expected: WAITS.
--   6. A  R6   Lock evidence: B waiting, blocked by A.     [SCREENSHOT 1]
--   7. A  R7   COMMIT.
--   8. B  (R5 returns) Expected: the SAME transaction_id N.
--   9. B  R8   COMMIT.
--   Part 2 — first caller rolls back
--  10. A  R9   BEGIN; call (ROLLBACK reference). Expected: an id M.
--  11. B  R10  BEGIN; identical call. Expected: WAITS.
--  12. A  R11  ROLLBACK.
--  13. B  (R10 returns) Expected: a NEW transaction_id, not M.
--  14. B  R12  COMMIT.
--  15. A  R13  Final verification.                          [SCREENSHOT 2]
--
-- "Expected" outcomes are what the script predicts. No screenshot or output of this run was saved; see the P3 analysis, Section 12.2.
-- ============================================================================


-- R1 — SESSION A (step 1): Identify.
SET application_name = 'P3_RETRY_A';

SELECT pg_backend_pid() AS session_pid,
       current_setting('application_name') AS session_name,
       current_setting('transaction_isolation') AS isolation_level;


-- R2 — SESSION B (step 2): Identify.
SET application_name = 'P3_RETRY_B';

SELECT pg_backend_pid() AS session_pid,
       current_setting('application_name') AS session_name,
       current_setting('transaction_isolation') AS isolation_level;


-- R3 — SESSION A (step 3): Pre-check (read-only).
-- Expected: references_in_use 0; record both opening balances
-- (100000.00 each if unchanged since p3_13).
SELECT w.wallet_number,
       w.balance AS opening_balance,
       (SELECT COUNT(*) FROM transactions
        WHERE reference IN ('P3L-RETRY-COMMIT-001',
                            'P3L-RETRY-ROLLBACK-001')) AS references_in_use
FROM wallets AS w
WHERE w.wallet_number IN ('P3LW000001', 'P3LW000002')
ORDER BY w.wallet_number;


-- ============================================================================
-- PART 1 — FIRST CALLER COMMITS
-- ============================================================================

-- R4 — SESSION A (step 4): First call, left uncommitted.
-- Expected: one transaction_id (call it N).
BEGIN;

SELECT public.korapay_transfer_funds(
    'P3LW000001', 'P3LW000002', 1.00, 'P3L-RETRY-COMMIT-001'
) AS transaction_id;


-- R5 — SESSION B (step 5): Identical call.
-- Expected: WAITS — its reference claim (INSERT ... ON CONFLICT) waits for
-- A's uncommitted row. After A commits: returns N, moves no money.
BEGIN;

SELECT public.korapay_transfer_funds(
    'P3LW000001', 'P3LW000002', 1.00, 'P3L-RETRY-COMMIT-001'
) AS transaction_id;


-- R6 — SESSION A (step 6): Lock evidence while B waits.
-- Expected: P3_RETRY_B active, wait_event_type Lock, blocked_by = A's PID.
--                                                          [SCREENSHOT 1]
SELECT pid, application_name, state, wait_event_type, wait_event,
       pg_blocking_pids(pid) AS blocked_by
FROM pg_stat_activity
WHERE application_name IN ('P3_RETRY_A', 'P3_RETRY_B')
ORDER BY application_name;


-- R7 — SESSION A (step 7): COMMIT. Expected: B's call then returns N.
COMMIT;


-- R8 — SESSION B (step 9): COMMIT.
COMMIT;


-- ============================================================================
-- PART 2 — FIRST CALLER ROLLS BACK
-- ============================================================================

-- R9 — SESSION A (step 10): First call, left uncommitted.
-- Expected: one transaction_id (call it M).
BEGIN;

SELECT public.korapay_transfer_funds(
    'P3LW000001', 'P3LW000002', 1.00, 'P3L-RETRY-ROLLBACK-001'
) AS transaction_id;


-- R10 — SESSION B (step 11): Identical call.
-- Expected: WAITS. After A rolls back, B's claim succeeds and B posts the
-- transfer itself, returning a NEW transaction_id (not M).
BEGIN;

SELECT public.korapay_transfer_funds(
    'P3LW000001', 'P3LW000002', 1.00, 'P3L-RETRY-ROLLBACK-001'
) AS transaction_id;


-- R11 — SESSION A (step 12): ROLLBACK. Expected: B's call then returns.
ROLLBACK;


-- R12 — SESSION B (step 14): COMMIT.
COMMIT;


-- ============================================================================
-- R13 — SESSION A (step 15): Final verification (read-only)
-- Expected for each reference: transaction_count 1, status SUCCESSFUL,
-- amount 1.00, ledger_entries 2 (one DEBIT, one CREDIT).
-- Expected balances: P3LW000001 = R3 opening - 2.00,
--                    P3LW000002 = R3 opening + 2.00, both reconciled;
-- open_experiment_transactions 0.                          [SCREENSHOT 2]
-- Wallet rows reuse the columns: status = reconciliation result,
-- amount = current balance, ledger_entries = all entries on that wallet.
-- ============================================================================
SELECT
    r.reference                                      AS item,
    COUNT(DISTINCT t.transaction_id)::TEXT           AS transaction_count,
    string_agg(DISTINCT t.status, ',')               AS status,
    MIN(t.amount)::TEXT                              AS amount,
    COUNT(le.ledger_entry_id)::TEXT                  AS ledger_entries,
    (COUNT(*) FILTER (WHERE le.entry_type = 'DEBIT'))::TEXT || ' DEBIT / '
      || (COUNT(*) FILTER (WHERE le.entry_type = 'CREDIT'))::TEXT || ' CREDIT' AS entry_types
FROM (VALUES ('P3L-RETRY-COMMIT-001'), ('P3L-RETRY-ROLLBACK-001')) AS r (reference)
LEFT JOIN transactions   AS t  ON t.reference = r.reference
LEFT JOIN ledger_entries AS le ON le.transaction_id = t.transaction_id
GROUP BY r.reference

UNION ALL

SELECT
    w.wallet_number,
    NULL,
    CASE WHEN w.balance = COALESCE(SUM(CASE le.entry_type WHEN 'CREDIT' THEN le.amount
                                                          WHEN 'DEBIT'  THEN -le.amount END), 0.00)
         THEN 'reconciled' ELSE 'MISMATCH' END,
    w.balance::TEXT,
    COUNT(le.ledger_entry_id)::TEXT,
    'open_experiment_transactions = ' || (
        SELECT COUNT(*) FROM pg_stat_activity
        WHERE application_name IN ('P3_RETRY_A', 'P3_RETRY_B')
          AND xact_start IS NOT NULL
          AND pid <> pg_backend_pid())::TEXT
FROM wallets AS w
LEFT JOIN ledger_entries AS le ON le.wallet_id = w.wallet_id
WHERE w.wallet_number IN ('P3LW000001', 'P3LW000002')
GROUP BY w.wallet_id, w.wallet_number, w.balance
ORDER BY 1;
