-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_18_lock_timeout.sql
-- Description:  LOCK TIMEOUT (additional experiment, pgAdmin, lab table only).
--               A holds a row lock on lab account 3. B sets
--               SET LOCAL lock_timeout = '3s' and requests the same row.
--               Instead of waiting indefinitely, B is cancelled after about
--               3 seconds (SQLSTATE 55P03). Only SELECT ... FOR UPDATE is
--               used, so no balance changes.
--
-- HOW TO RUN: open this file in TWO pgAdmin Query Tool tabs (A and B).
-- Highlight ONE section at a time (F5); never the whole file.
-- "Auto rollback on error" OFF in both tabs.
--
-- EXECUTION ORDER:
--   1. A  T1  Identify A; show account 3 (opening values).
--   2. B  T2  Identify B.
--   3. A  T3  BEGIN; lock account 3.
--   4. B  T4  BEGIN; SET LOCAL lock_timeout = '3s'; request account 3.
--             Expected: ERROR after about 3 s, SQLSTATE 55P03.  [SCREENSHOT 1]
--   5. B  T5  ROLLBACK.
--   6. A  T6  COMMIT.
--   7. B  T7  Verify: account 3 unchanged, lock_timeout back to default,
--             no open experiment transactions.                [SCREENSHOT 2]
--
-- All outcomes marked "Expected" are predictions until run.
-- ============================================================================


-- T1 — SESSION A (step 1): Identify; opening values of account 3.
SET application_name = 'P3_LOCKTIMEOUT_A';

SELECT pg_backend_pid()                    AS session_pid,
       current_setting('application_name') AS session_name,
       a.account_id,
       a.balance,
       a.updated_at
FROM p3_lab.accounts AS a
WHERE a.account_id = 3;


-- T2 — SESSION B (step 2): Identify.
-- Expected: a different PID; lock_timeout 0 (= wait indefinitely, default).
SET application_name = 'P3_LOCKTIMEOUT_B';

SELECT pg_backend_pid()                    AS session_pid,
       current_setting('application_name') AS session_name,
       current_setting('lock_timeout')     AS lock_timeout;


-- T3 — SESSION A (step 3): Begin and lock account 3.
-- Expected: returns account 3 immediately; A now holds the row lock.
BEGIN;

SELECT account_id, balance
FROM p3_lab.accounts
WHERE account_id = 3
FOR UPDATE;


-- T4 — SESSION B (step 4): Bounded wait for the same row.
-- SET LOCAL applies only to this transaction.
-- Expected: after about 3 s,
--   ERROR: canceling statement due to lock timeout   (SQLSTATE 55P03)
-- B's transaction is then aborted.                         [SCREENSHOT 1]
BEGIN;

SET LOCAL lock_timeout = '3s';

SELECT account_id, balance
FROM p3_lab.accounts
WHERE account_id = 3
FOR UPDATE;


-- T5 — SESSION B (step 5): End the aborted transaction.
-- Expected: ROLLBACK succeeds.
ROLLBACK;


-- T6 — SESSION A (step 6): Release the lock.
-- Expected: COMMIT succeeds (nothing was updated).
COMMIT;


-- T7 — SESSION B (step 7): Verify.
-- Expected: balance and updated_at identical to T1; lock_timeout 0 again
-- (SET LOCAL ended with the transaction); open_experiment_transactions 0.
--                                                          [SCREENSHOT 2]
SELECT a.account_id,
       a.balance,
       a.updated_at,
       current_setting('lock_timeout') AS lock_timeout_now,
       (SELECT COUNT(*)
        FROM pg_stat_activity
        WHERE application_name IN ('P3_LOCKTIMEOUT_A', 'P3_LOCKTIMEOUT_B')
          AND xact_start IS NOT NULL
          AND pid <> pg_backend_pid()) AS open_experiment_transactions
FROM p3_lab.accounts AS a
WHERE a.account_id = 3;
