-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_LostUpdateSessionA.sql
-- Description:  LOST UPDATE DEMONSTRATION — SESSION A (pgAdmin Query Tool).
--               Partner file: ..._P3_14_LostUpdateSessionB.sql
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
--   1. In pgAdmin, open a Query Tool on korapay_wallet and load this file:
--      this tab is SESSION A. Open a SECOND Query Tool on korapay_wallet and
--      load the Session B file: that tab is SESSION B. Each Query Tool tab is
--      its own database connection.
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
-- SECTION A0 (step 1): Identify Session A
-- Expected: P3_LOST_UPDATE_A, default isolation level read committed.
-- ============================================================================
SET application_name = 'P3_LOST_UPDATE_A';

SELECT
    pg_backend_pid()                         AS session_pid,
    current_setting('application_name')      AS session_name,
    current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- SECTION A1 (step 3): Reset accounts 1 and 2 to 1,000.00 (Part 1 start)
-- Run outside any transaction. The DO block refuses to reset while either
-- experiment session has an open transaction. Only the two named lab
-- sessions are checked; unrelated pgAdmin sessions are ignored.
-- Expected: accounts 1 and 2 at 1,000.00.
-- ============================================================================
DO $$
DECLARE
    v_open BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_open
    FROM pg_stat_activity
    WHERE application_name IN ('P3_LOST_UPDATE_A', 'P3_LOST_UPDATE_B')
      AND pid <> pg_backend_pid()
      AND xact_start IS NOT NULL;

    IF v_open > 0 THEN
        RAISE EXCEPTION 'Reset refused: % experiment session(s) still have an open transaction.', v_open;
    END IF;

    UPDATE p3_lab.accounts
    SET balance    = 1000.00,
        updated_at = CURRENT_TIMESTAMP
    WHERE account_id IN (1, 2);
END $$;

SELECT account_id, account_name, balance, updated_at
FROM p3_lab.accounts
WHERE account_id IN (1, 2)
ORDER BY account_id;


-- ============================================================================
-- PART 1 — UNSAFE READ-THEN-WRITE
-- ============================================================================

-- ============================================================================
-- SECTION A2 (step 4): Begin and store the initial read of account 1
-- The balance is copied into a temporary table that exists only in this
-- session and is dropped at COMMIT, as an application would keep the value
-- it read in memory.
-- Expected: a_initial_balance 1000.00; isolation_level read committed.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

CREATE TEMPORARY TABLE p3_a_initial_read ON COMMIT DROP AS
SELECT account_id, balance AS a_initial_balance
FROM p3_lab.accounts
WHERE account_id = 1;

SELECT
    account_id,
    a_initial_balance,
    current_setting('transaction_isolation') AS isolation_level
FROM p3_a_initial_read;


-- ============================================================================
-- SECTION A3a (step 6): UNSAFE write — absolute value from the stored read
-- The new balance is calculated from the value stored in A2, not from the
-- current row.
-- Expected: RETURNING balance 900.00.
-- ============================================================================
UPDATE p3_lab.accounts
SET balance    = (SELECT a_initial_balance FROM p3_a_initial_read) - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1
RETURNING account_id, balance;


-- ============================================================================
-- SECTION A3b (step 7): COMMIT
-- Expected: COMMIT succeeds; the temporary table is dropped.
-- ============================================================================
COMMIT;


-- ============================================================================
-- SECTION A4 (step 10): Verify Part 1 (after Session B's B2b COMMIT)
-- Expected: balance 900.00; expected_correct_balance 800.00;
--           amount_lost 100.00 (one withdrawal of 100.00 was lost).
-- ============================================================================
SELECT
    account_id,
    balance,
    800.00            AS expected_correct_balance,
    balance - 800.00  AS amount_lost
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- PART 2 — SAFE RELATIVE UPDATE
-- ============================================================================

-- ============================================================================
-- SECTION A5 (step 11): Reset account 1 to 1,000.00 (Part 2 start)
-- Same scoped check as A1. Run outside any transaction.
-- Expected: account 1 at 1,000.00.
-- ============================================================================
DO $$
DECLARE
    v_open BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_open
    FROM pg_stat_activity
    WHERE application_name IN ('P3_LOST_UPDATE_A', 'P3_LOST_UPDATE_B')
      AND pid <> pg_backend_pid()
      AND xact_start IS NOT NULL;

    IF v_open > 0 THEN
        RAISE EXCEPTION 'Reset refused: % experiment session(s) still have an open transaction.', v_open;
    END IF;

    UPDATE p3_lab.accounts
    SET balance    = 1000.00,
        updated_at = CURRENT_TIMESTAMP
    WHERE account_id = 1;
END $$;

SELECT account_id, balance, updated_at
FROM p3_lab.accounts
WHERE account_id = 1;


-- ============================================================================
-- SECTION A6 (step 12): Begin and apply a relative update; leave OPEN
-- SAFE: the database computes balance - 100.00 from the current row value
-- and keeps a row lock on account 1 until COMMIT.
-- Expected: RETURNING balance 900.00 (visible only to Session A for now).
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

UPDATE p3_lab.accounts
SET balance    = balance - 100.00,
    updated_at = CURRENT_TIMESTAMP
WHERE account_id = 1
RETURNING account_id, balance, current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- SECTION A7 (step 14): Lock evidence (run while Session B's B3 is waiting)
-- Only the two experiment sessions are listed.
-- Expected: P3_LOST_UPDATE_B active, wait_event_type Lock, blocked_by
--           containing Session A's PID (from A0). P3_LOST_UPDATE_A shows
--           active because it is running this query.
-- ============================================================================
SELECT
    pid,
    application_name,
    state,
    wait_event_type,
    wait_event,
    pg_blocking_pids(pid) AS blocked_by
FROM pg_stat_activity
WHERE application_name IN ('P3_LOST_UPDATE_A', 'P3_LOST_UPDATE_B')
ORDER BY application_name;


-- ============================================================================
-- SECTION A8 (step 15): COMMIT — releases the row lock
-- Expected: Session B's waiting UPDATE then completes with balance 800.00.
-- ============================================================================
COMMIT;
