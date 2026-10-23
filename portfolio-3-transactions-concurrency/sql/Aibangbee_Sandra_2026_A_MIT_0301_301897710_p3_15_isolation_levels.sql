-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_15_isolation_levels.sql
-- Description:  READ COMMITTED versus REPEATABLE READ (pgAdmin Query Tool).
--
-- WHAT IS DEMONSTRATED (lab table p3_lab.accounts only):
--   Part 1 — READ COMMITTED: each statement sees the latest committed data.
--            Session A reads account 1 (1,000.00); Session B commits 900.00;
--            A reads again inside the SAME transaction and sees 900.00
--            (a non-repeatable read).
--   Part 2 — REPEATABLE READ: the transaction keeps one snapshot, taken at
--            its first query. A reads 1,000.00; B commits 900.00; A still
--            sees 1,000.00. When A tries to update that row, PostgreSQL
--            raises a serialization failure (SQLSTATE 40001) rather than
--            overwrite B's committed change. A rolls back and retries in a
--            fresh transaction, which sees 900.00 and produces 800.00.
--
-- SCOPE:
--   Only p3_lab.accounts is changed. The KoraPay financial tables
--   (customers, wallets, transactions, ledger_entries) are not touched.
--
-- ****************************************************************************
-- HOW TO RUN: TWO SEPARATE pgAdmin QUERY TOOL CONNECTIONS.
--   * Open this file in TWO Query Tool tabs on korapay_wallet. Use one tab
--     only for the "SESSION A" sections and the other only for the
--     "SESSION B" sections. Each tab is its own database connection.
--   * Highlight ONE section at a time and execute it (F5). NEVER run the
--     whole file. Follow the SHARED EXECUTION ORDER below.
--   * Keep "Auto commit" ON (the default) and turn "Auto rollback on error"
--     OFF in both tabs, so the error in step 12 leaves A's transaction
--     aborted until the explicit ROLLBACK in step 13.
--   * pgAdmin shows only the LAST result of a selection; each section ends
--     with the statement whose result is the evidence.
--
-- SCREENSHOTS (three key results; capture the whole pgAdmin window):
--   1. Step 6  (A, S6)  — READ COMMITTED second read: 900.00.
--   2. Step 12 (A, S12) — REPEATABLE READ update: SQLSTATE 40001 error.
--   3. Step 14 (A, S14) — successful retry: RETURNING 800.00.
-- ****************************************************************************
--
-- SHARED EXECUTION ORDER:
--   Setup
--    1. A  S1   Identify Session A.
--    2. B  S2   Identify Session B.
--   Part 1 — READ COMMITTED
--    3. A  S3   Reset account 1 to 1,000.00 (both sessions outside
--               transactions).
--    4. A  S4   BEGIN READ COMMITTED; first read (expected 1,000.00).
--    5. B  S5   Change account 1 to 900.00 and COMMIT.
--    6. A  S6   Second read in the same transaction (expected 900.00).
--    7. A  S7   COMMIT.
--   Part 2 — REPEATABLE READ
--    8. A  S8   Reset account 1 to 1,000.00 (both sessions outside
--               transactions).
--    9. A  S9   BEGIN REPEATABLE READ; first read (expected 1,000.00).
--   10. B  S10  Change account 1 to 900.00 and COMMIT.
--   11. A  S11  Second read in the same transaction (expected 1,000.00).
--   12. A  S12  Relative UPDATE (expected ERROR, SQLSTATE 40001).
--   13. A  S13  ROLLBACK.
--   14. A  S14  Fresh REPEATABLE READ transaction; retry the relative UPDATE
--               (expected RETURNING 800.00).
--   15. A  S15  COMMIT.
--   16. A  S16  Final verification (expected 800.00; no open experiment
--               transactions).
--
-- All values marked "Expected" are predictions, not recorded results.
-- ============================================================================


-- ============================================================================
-- S1 — SESSION A (step 1): Identify Session A
-- Expected: P3_ISOLATION_A, default isolation level read committed.
-- ============================================================================
SET application_name = 'P3_ISOLATION_A';

SELECT
    pg_backend_pid()                         AS session_pid,
    current_setting('application_name')      AS session_name,
    current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- S2 — SESSION B (step 2): Identify Session B
-- Expected: P3_ISOLATION_B, default isolation level read committed.
-- ============================================================================
SET application_name = 'P3_ISOLATION_B';

SELECT
    pg_backend_pid()                         AS session_pid,
    current_setting('application_name')      AS session_name,
    current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- PART 1 — READ COMMITTED
-- ============================================================================

-- ============================================================================
-- S3 — SESSION A (step 3): Safe reset of account 1 to 1,000.00
-- Refuses to run if either experiment session has an open transaction.
-- Only P3_ISOLATION_A and P3_ISOLATION_B are checked; other pgAdmin
-- sessions are ignored.
-- Expected: account 1 at 1,000.00.
-- ============================================================================
BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_stat_activity
        WHERE application_name IN ('P3_ISOLATION_A', 'P3_ISOLATION_B')
          AND pid <> pg_backend_pid()
          AND xact_start IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Reset refused: an experiment session still has an open transaction.';
    END IF;

    UPDATE p3_lab.accounts
    SET balance    = 1000.00,
        updated_at = CURRENT_TIMESTAMP
    WHERE account_id = 1;
END $$;

COMMIT;

SELECT account_id, balance FROM p3_lab.accounts WHERE account_id = 1;


-- ============================================================================
-- S4 — SESSION A (step 4): Begin READ COMMITTED and read account 1
-- Expected: balance 1000.00; isolation_level read committed.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT
    account_id,
    balance,
    current_setting('transaction_isolation') AS isolation_level
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- S5 — SESSION B (step 5): Change account 1 to 900.00 and commit
-- Expected: final SELECT shows the committed balance 900.00.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

UPDATE p3_lab.accounts
SET balance    = balance - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1;

COMMIT;

SELECT account_id, balance AS committed_balance
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- S6 — SESSION A (step 6): Second read in the SAME transaction
-- Under READ COMMITTED each statement takes a new snapshot, so A now sees
-- B's committed change: a non-repeatable read.
-- Expected: balance 900.00.            >>> SCREENSHOT 1 <<<
-- ============================================================================
SELECT
    account_id,
    balance,
    current_setting('transaction_isolation') AS isolation_level
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- S7 — SESSION A (step 7): End the READ COMMITTED transaction
-- Expected: COMMIT succeeds.
-- ============================================================================
COMMIT;


-- ============================================================================
-- PART 2 — REPEATABLE READ
-- ============================================================================

-- ============================================================================
-- S8 — SESSION A (step 8): Safe reset of account 1 to 1,000.00
-- Both sessions must be outside transactions (checked as in S3).
-- Expected: account 1 at 1,000.00.
-- ============================================================================
BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_stat_activity
        WHERE application_name IN ('P3_ISOLATION_A', 'P3_ISOLATION_B')
          AND pid <> pg_backend_pid()
          AND xact_start IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Reset refused: an experiment session still has an open transaction.';
    END IF;

    UPDATE p3_lab.accounts
    SET balance    = 1000.00,
        updated_at = CURRENT_TIMESTAMP
    WHERE account_id = 1;
END $$;

COMMIT;

SELECT account_id, balance FROM p3_lab.accounts WHERE account_id = 1;


-- ============================================================================
-- S9 — SESSION A (step 9): Begin REPEATABLE READ and read account 1
-- The transaction's snapshot is taken at this first query and kept until
-- the transaction ends.
-- Expected: balance 1000.00; isolation_level repeatable read.
-- ============================================================================
BEGIN ISOLATION LEVEL REPEATABLE READ;

SELECT
    account_id,
    balance,
    current_setting('transaction_isolation') AS isolation_level
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- S10 — SESSION B (step 10): Change account 1 to 900.00 and commit
-- Expected: final SELECT shows the committed balance 900.00.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

UPDATE p3_lab.accounts
SET balance    = balance - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1;

COMMIT;

SELECT account_id, balance AS committed_balance
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- S11 — SESSION A (step 11): Second read in the SAME transaction
-- Under REPEATABLE READ, A keeps reading from its original snapshot and does
-- not see B's committed 900.00.
-- Expected: balance 1000.00.
-- ============================================================================
SELECT
    account_id,
    balance,
    current_setting('transaction_isolation') AS isolation_level
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- S12 — SESSION A (step 12): Relative UPDATE on the changed row
-- The row was changed and committed by B after A's snapshot was taken.
-- REPEATABLE READ cannot apply A's update on top of a version it cannot
-- see, so PostgreSQL rejects it instead of losing B's change.
-- Expected: ERROR: could not serialize access due to concurrent update
--           SQLSTATE 40001. A's transaction is now aborted.
--                                       >>> SCREENSHOT 2 <<<
-- ============================================================================
UPDATE p3_lab.accounts
SET balance    = balance - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1
RETURNING account_id, balance;


-- ============================================================================
-- S13 — SESSION A (step 13): ROLLBACK the aborted transaction
-- Expected: ROLLBACK succeeds. (If "Auto rollback on error" was ON, pgAdmin
-- has already rolled back and this reports "there is no transaction in
-- progress".)
-- ============================================================================
ROLLBACK;


-- ============================================================================
-- S14 — SESSION A (step 14): Retry in a FRESH transaction
-- A new REPEATABLE READ transaction takes a new snapshot, which includes B's
-- committed 900.00, so the same relative UPDATE now succeeds.
-- Expected: RETURNING balance 800.00; isolation_level repeatable read.
--                                       >>> SCREENSHOT 3 <<<
-- ============================================================================
BEGIN ISOLATION LEVEL REPEATABLE READ;

UPDATE p3_lab.accounts
SET balance    = balance - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1
RETURNING account_id, balance, current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- S15 — SESSION A (step 15): COMMIT the successful retry
-- Expected: COMMIT succeeds.
-- ============================================================================
COMMIT;


-- ============================================================================
-- S16 — SESSION A (step 16): Final verification
-- Expected: balance 800.00; correct = true; open_experiment_transactions 0.
-- ============================================================================
SELECT
    account_id,
    balance,
    800.00            AS expected_balance,
    balance = 800.00  AS correct,
    (SELECT COUNT(*)
     FROM pg_stat_activity
     WHERE application_name IN ('P3_ISOLATION_A', 'P3_ISOLATION_B')
       AND xact_start IS NOT NULL
       AND pid <> pg_backend_pid()) AS open_experiment_transactions
FROM p3_lab.accounts
WHERE account_id = 1;
