-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_LostUpdateSessionB.sql
-- Description:  LOST UPDATE DEMONSTRATION — SESSION B (pgAdmin Query Tool).
--               Partner file: ..._P3_14_LostUpdateSessionA.sql
--
-- WHAT IS DEMONSTRATED (READ COMMITTED, lab table only):
--   Part 1 — UNSAFE: each session stores the balance it reads (1,000.00) in
--            its own temporary table, then later writes the ABSOLUTE value
--            stored balance - 100.00 = 900.00. Two withdrawals of 100.00
--            leave 900.00 instead of 800.00: one update is lost.
--   Part 2 — SAFE: each session runs UPDATE ... SET balance = balance - 100.00.
--            Session B waits for Session A's row lock, then applies its update
--            to the committed 900.00, giving the correct 800.00.
--
-- SCOPE:
--   Only p3_lab.accounts and session-local temporary tables are changed.
--   The KoraPay financial tables (customers, wallets, transactions,
--   ledger_entries) are not touched.
--
-- ****************************************************************************
-- HOW TO RUN: TWO SEPARATE pgAdmin QUERY TOOL CONNECTIONS.
--   1. In pgAdmin, open a Query Tool on korapay_wallet and load the Session A
--      file: that tab is SESSION A. Open a SECOND Query Tool on
--      korapay_wallet and load this file: this tab is SESSION B. Each Query
--      Tool tab is its own database connection.
--   2. Highlight ONE section at a time and execute it (F5). NEVER run the
--      whole file. Follow the SHARED EXECUTION ORDER below, switching tabs.
--   3. pgAdmin shows only the LAST result of a selection, so each section
--      ends with the statement whose result is the evidence.
--   4. Turn OFF "Auto rollback on error" for both tabs (toolbar / Query Tool
--      options), so an error does not silently end a transaction.
--   5. If a statement fails unexpectedly inside a transaction, run ROLLBACK;
--      in that tab and restart from the part's reset step.
--
-- SCREENSHOTS (capture the whole pgAdmin window, including the Data Output
-- or Messages panel and the clock):
--   * A0 and B0 — session names, PIDs and isolation level.
--   * A1 — accounts 1 and 2 reset to 1,000.00.
--   * A2 and B1 — each session's stored initial read of 1,000.00.
--   * A3a and B2a — each unsafe UPDATE returning 900.00.
--   * A4 — final 900.00 and amount_lost 100.00.
--   * A6 — Session A's uncommitted 900.00.
--   * B3 while waiting — Session B's "Waiting for the query to complete".
--   * A7 — lock evidence (Session B blocked by Session A).
--   * B3 after the wait — RETURNING 800.00.
--   * B5 — final 800.00 and no open experiment transactions.
-- ****************************************************************************
--
-- SHARED EXECUTION ORDER (same list in both files):
--   Setup
--    1. A  A0   Identify Session A.
--    2. B  B0   Identify Session B.
--    3. A  A1   Check no open experiment transactions; reset accounts 1 and 2
--               to 1,000.00.
--   Part 1 — unsafe read-then-write
--    4. A  A2   BEGIN READ COMMITTED; store initial read of account 1 in a
--               temporary table (expected 1,000.00).
--    5. B  B1   BEGIN READ COMMITTED; store initial read of account 1 in a
--               temporary table (expected 1,000.00).
--    6. A  A3a  UPDATE to stored value - 100.00 (expected 900.00).
--    7. A  A3b  COMMIT.
--    8. B  B2a  UPDATE to stored value - 100.00 (expected 900.00, no wait).
--    9. B  B2b  COMMIT.
--   10. A  A4   Verify: expected 900.00, amount_lost 100.00.
--   Part 2 — safe relative update
--   11. A  A5   Check no open experiment transactions; reset account 1 to
--               1,000.00.
--   12. A  A6   BEGIN READ COMMITTED; balance = balance - 100.00
--               (expected 900.00); leave the transaction OPEN.
--   13. B  B3   BEGIN READ COMMITTED; balance = balance - 100.00
--               -> expected to WAIT for Session A's row lock.
--   14. A  A7   Lock evidence: expected Session B waiting on Lock, blocked
--               by Session A.
--   15. A  A8   COMMIT.
--   16. B  (B3 finishes on its own; expected RETURNING 800.00)
--   17. B  B4   COMMIT.
--   18. B  B5   Verify: expected 800.00; no open experiment transactions.
--
-- "Expected" values are what the script predicts. Recorded results: the P3 analysis, Section 8.
-- ============================================================================


-- ============================================================================
-- SECTION B0 (step 2): Identify Session B
-- Expected: P3_LOST_UPDATE_B, default isolation level read committed.
-- ============================================================================
SET application_name = 'P3_LOST_UPDATE_B';

SELECT
    pg_backend_pid()                         AS session_pid,
    current_setting('application_name')      AS session_name,
    current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- PART 1 — UNSAFE READ-THEN-WRITE
-- ============================================================================

-- ============================================================================
-- SECTION B1 (step 5): Begin and store the initial read of account 1
-- Run after Session A's A2 and BEFORE Session A's A3a, so both sessions
-- store the same balance before either writes. The value is copied into a
-- temporary table that exists only in this session and is dropped at COMMIT.
-- Expected: b_initial_balance 1000.00; isolation_level read committed.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

CREATE TEMPORARY TABLE p3_b_initial_read ON COMMIT DROP AS
SELECT account_id, balance AS b_initial_balance
FROM p3_lab.accounts
WHERE account_id = 1;

SELECT
    account_id,
    b_initial_balance,
    current_setting('transaction_isolation') AS isolation_level
FROM p3_b_initial_read;


-- ============================================================================
-- SECTION B2a (step 8): UNSAFE write — absolute value from the stored read
-- Session A has already committed 900.00, but Session B still uses the
-- 1,000.00 it stored in B1. Its UPDATE does not wait (A has committed) and
-- overwrites the row with the same stale result.
-- Expected: RETURNING balance 900.00; Session A's withdrawal is lost.
-- ============================================================================
UPDATE p3_lab.accounts
SET balance    = (SELECT b_initial_balance FROM p3_b_initial_read) - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1
RETURNING account_id, balance;


-- ============================================================================
-- SECTION B2b (step 9): COMMIT
-- Expected: COMMIT succeeds; the temporary table is dropped.
-- ============================================================================
COMMIT;


-- ============================================================================
-- PART 2 — SAFE RELATIVE UPDATE
-- ============================================================================

-- ============================================================================
-- SECTION B3 (step 13): Begin and apply a relative update
-- Run while Session A's A6 transaction is still OPEN.
-- Expected: this UPDATE WAITS ("Waiting for the query to complete...")
-- because Session A holds the row lock on account 1. After Session A commits
-- (A8), it re-reads the committed row (900.00) and completes.
-- Expected after the wait: RETURNING balance 800.00.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

UPDATE p3_lab.accounts
SET balance    = balance - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1
RETURNING account_id, balance, current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- SECTION B4 (step 17): COMMIT
-- Expected: COMMIT succeeds.
-- ============================================================================
COMMIT;


-- ============================================================================
-- SECTION B5 (step 18): Verify Part 2
-- Expected: balance 800.00; correct = true (both withdrawals applied);
--           open_experiment_transactions = 0.
-- ============================================================================
SELECT
    account_id,
    balance,
    800.00            AS expected_correct_balance,
    balance = 800.00  AS correct,
    (SELECT COUNT(*)
     FROM pg_stat_activity
     WHERE application_name IN ('P3_LOST_UPDATE_A', 'P3_LOST_UPDATE_B')
       AND pid <> pg_backend_pid()
       AND xact_start IS NOT NULL) AS open_experiment_transactions
FROM p3_lab.accounts
WHERE account_id = 1;
