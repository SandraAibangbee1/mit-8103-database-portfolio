-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_16_DeadlockDemo.sql
-- Description:  DELIBERATE DEADLOCK (pgAdmin Query Tool, lab table only).
--               A locks account 1 then 2; B locks account 2 then 1.
--               PostgreSQL detects the cycle and aborts one session with
--               SQLSTATE 40P01. Only SELECT ... FOR UPDATE is used, so no
--               balance changes. Only p3_lab.accounts is read and locked.
--
-- HOW TO RUN:
--   Open this file in TWO pgAdmin Query Tool tabs on korapay_wallet (one tab
--   = Session A, the other = Session B). Highlight ONE section at a time and
--   press F5. NEVER run the whole file. Turn "Auto rollback on error" OFF in
--   both tabs.
--
-- SHARED EXECUTION ORDER:
--    1. A  D1  Identify Session A.
--    2. B  D2  Identify Session B (expected: a different PID).
--    3. A  D3  Opening balances of accounts 1 and 2 (no reset).
--    4. A  D4  BEGIN; lock account 1.
--    5. B  D5  BEGIN; lock account 2.
--    6. A  D6  Request account 2 -> expected to WAIT (B holds it).
--    7. B  D7  Request account 1 -> deadlock (expected within about 1 s).
--    8. Victim: whichever session shows ERROR 40P01 runs its ROLLBACK
--               section (D8A or D8B).
--    9. Survivor: once its waiting query has returned a row, runs its
--               COMMIT section (D9A or D9B).
--   10. A  D10 Verify balances unchanged and no open experiment transactions.
--
-- "Expected" outcomes are what the script predicts. Recorded results: the P3 analysis, Section 10.
-- ============================================================================


-- ============================================================================
-- D1 — SESSION A (step 1): Identify
-- Expected: P3_DEADLOCK_A, its own PID.
-- ============================================================================
SET application_name = 'P3_DEADLOCK_A';

SELECT pg_backend_pid() AS session_pid,
       current_setting('application_name') AS session_name;


-- ============================================================================
-- D2 — SESSION B (step 2): Identify
-- Expected: P3_DEADLOCK_B, a PID different from Session A's.
-- ============================================================================
SET application_name = 'P3_DEADLOCK_B';

SELECT pg_backend_pid() AS session_pid,
       current_setting('application_name') AS session_name;


-- ============================================================================
-- D3 — SESSION A (step 3): Opening balances (no reset)
-- Record these values; D10 must show the same balances.
-- deadlock_timeout is how long a waiting session waits before PostgreSQL
-- checks for a deadlock (default 1s).
-- ============================================================================
SELECT account_id,
       balance,
       updated_at,
       current_setting('deadlock_timeout') AS deadlock_timeout
FROM p3_lab.accounts
WHERE account_id IN (1, 2)
ORDER BY account_id;


-- ============================================================================
-- D4 — SESSION A (step 4): Begin and lock account 1
-- Expected: returns account 1 immediately.
-- ============================================================================
BEGIN;

SELECT account_id, balance
FROM p3_lab.accounts
WHERE account_id = 1
FOR UPDATE;


-- ============================================================================
-- D5 — SESSION B (step 5): Begin and lock account 2
-- Expected: returns account 2 immediately.
-- ============================================================================
BEGIN;

SELECT account_id, balance
FROM p3_lab.accounts
WHERE account_id = 2
FOR UPDATE;


-- ============================================================================
-- D6 — SESSION A (step 6): Request account 2
-- Expected: WAITS ("Waiting for the query to complete"), because Session B
-- holds account 2.
-- ============================================================================
SELECT account_id, balance
FROM p3_lab.accounts
WHERE account_id = 2
FOR UPDATE;


-- ============================================================================
-- D7 — SESSION B (step 7): Request account 1 — creates the deadlock
-- A waits for B (account 2) and B now waits for A (account 1).
-- Expected: within about deadlock_timeout, PostgreSQL aborts ONE of the two
-- sessions with:
--   ERROR: deadlock detected   (SQLSTATE 40P01)
-- Either session may be chosen as the victim. The other session's waiting
-- query then returns its row.
-- ============================================================================
SELECT account_id, balance
FROM p3_lab.accounts
WHERE account_id = 1
FOR UPDATE;


-- ============================================================================
-- STEP 8 — VICTIM ONLY: run the ROLLBACK section in the tab that shows
-- ERROR 40P01. Its transaction is aborted and its locks are released.
-- ============================================================================

-- D8A — SESSION A, only if Session A received 40P01.
ROLLBACK;

-- D8B — SESSION B, only if Session B received 40P01.
ROLLBACK;


-- ============================================================================
-- STEP 9 — SURVIVOR ONLY: after its waiting query has returned a row, run
-- the COMMIT section in the other tab. Nothing was updated, so COMMIT only
-- ends the transaction and releases its locks.
-- ============================================================================

-- D9A — SESSION A, only if Session B was the victim.
COMMIT;

-- D9B — SESSION B, only if Session A was the victim.
COMMIT;


-- ============================================================================
-- D10 — SESSION A (step 10): Verify
-- Expected: balances and updated_at identical to D3;
--           open_experiment_transactions = 0.
-- ============================================================================
SELECT account_id,
       balance,
       updated_at,
       (SELECT COUNT(*)
        FROM pg_stat_activity
        WHERE application_name IN ('P3_DEADLOCK_A', 'P3_DEADLOCK_B')
          AND xact_start IS NOT NULL
          AND pid <> pg_backend_pid()) AS open_experiment_transactions
FROM p3_lab.accounts
WHERE account_id IN (1, 2)
ORDER BY account_id;
