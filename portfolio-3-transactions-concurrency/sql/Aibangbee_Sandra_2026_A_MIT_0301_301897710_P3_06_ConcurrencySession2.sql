-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_06_ConcurrencySession2.sql
-- Description:  DEMONSTRATION 3 — Concurrent spending from one wallet.
--               SESSION 2: checks the opening balances, then competes with
--               Session 1 to spend NGN 8,000.00 from P3W0000001 (to
--               P3W0000003). It waits for Session 1's row lock, then sees the
--               committed balance and is rejected.
--
-- WHAT THIS SESSION DID:
--   This was a validation-only attempt labelled P3-CONC-002. No second
--   transaction row or ledger entry was inserted, and no second posting
--   routine was executed. The attempt ends with ROLLBACK, so this session
--   changed no data.
--
-- WHY THE WAIT MATTERS (READ COMMITTED + SELECT ... FOR UPDATE):
--   Without the lock, Session 2 could read the stale balance 9,000.00 and
--   approve a second 8,000.00 transfer. With FOR UPDATE it must wait for
--   Session 1's lock on P3W0000001. When Session 1 commits, PostgreSQL
--   re-reads the latest committed version of the locked row, so Session 2
--   sees 1,000.00 and the insufficient-funds check rejects the transfer.
--   Because both sessions lock in ascending wallet_id order, Session 2 waits
--   on P3W0000001 before taking any other wallet lock.
--
-- RECORDED EVIDENCE (historical only, never used in the SQL below):
--   P3_SESSION_1 PID = 39364
--   P3_SESSION_2 PID = 41144
--
-- TWO ATTEMPTS:
--   The locking test was run twice. The first attempt ended when a syntax
--   error from leftover pasted text aborted Session 1's transaction; both
--   sessions were rolled back and the test was repeated successfully. By
--   their clock times, P3_23 (waiting) comes from the first attempt and
--   P3_27 (after the wait) from the repeat. No single wait duration is
--   reported across them.
--
-- SOURCE OF THE SQL TEXT:
--   Every section below matches the SQL visible in screenshots P3_20, P3_21,
--   P3_23/P3_27 and P3_28. The ROLLBACK in S2-E is the recorded step; its
--   message was not captured as a screenshot.
--
-- ****************************************************************************
-- WARNING: P3-CONC-001 HAS ALREADY BEEN COMMITTED IN THE CURRENT DATABASE.
-- Session 1's posting (p3_05, S1-D) must not be rerun there. Rerunning this
-- file alone would not wait for anything and would only repeat the
-- rejection against the current balance.
-- ****************************************************************************
--
-- ****************************************************************************
-- HOW TO RUN: SEPARATE pgAdmin QUERY TOOL TABS, ONE PER FILE, SECTION BY
-- SECTION. NEVER RUN AN ENTIRE FILE AT ONCE. Highlight one section and
-- execute it. Each tab is a separate database session and must stay open
-- throughout.
-- If pgAdmin "Auto rollback on error" is ON, pgAdmin rolls back after the
-- S2-D error and S2-E reports "there is no transaction in progress".
-- ****************************************************************************
--
-- EXECUTION ORDER ACROSS THE THREE SESSIONS (successful attempt):
--    1. Session 1  S1-A  Identify Session 1 (P3_19).
--    2. Session 2  S2-A  Identify Session 2 (P3_20).
--    3. Session 2  S2-B  Opening balances 9,000.00 / 1,000.00 / 0.00 (P3_21).
--    4. Session 1  S1-B  BEGIN; lock P3W0000001 and P3W0000002 FOR UPDATE
--                        (P3_22).
--    5. Session 2  S2-C  BEGIN; request locks on P3W0000001 and P3W0000003.
--                        -> WAITS: Session 1 holds the P3W0000001 row lock
--                        (P3_23).
--    6. Session 1  S1-C  Blocking query (P3_24).
--    7. Session 1  S1-D  ONE DO block: validation and posting of P3-CONC-001.
--                        Transaction left OPEN (P3_25).
--    8. Observer   O-A   Visibility check before commit: 9,000.00 /
--                        1,000.00, visible_transfer_count 0 (P3_26).
--    9. Session 1  S1-E  COMMIT.
--   10. Session 2  (S2-C finishes on its own) sender balance 1,000.00 (P3_27).
--   11. Session 2  S2-D  Validation-only DO block (P3-CONC-002) raises
--                        insufficient funds (P3_28).
--   12. Session 2  S2-E  ROLLBACK.
--   13. Observer   O-A   Visibility check after commit: 1,000.00 / 9,000.00,
--                        visible_transfer_count 1 (P3_29).
--   14. Observer   O-B   Reconciliation of all three P3 wallets (P3_30).
--   15. Observer   O-C   Verification of the saved transfer (recorded as
--                        P3_32, after the duplicate-reference test).
-- ============================================================================


-- ============================================================================
-- SECTION S2-A (step 2): Identify this session (as shown in P3_20)
-- Recorded: korapay_wallet, session_id 41144, P3_SESSION_2, read committed.
-- ============================================================================
SET application_name = 'P3_SESSION_2';

SELECT
    current_database() AS database_name,
    pg_backend_pid() AS session_id,
    current_setting('application_name') AS session_name,
    current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- SECTION S2-B (step 3): Opening balances, before either lock request
-- (as shown in P3_21)
-- Read-only; runs outside any transaction block.
-- Recorded: P3W0000001 9,000.00, P3W0000002 1,000.00, P3W0000003 0.00,
-- all ACTIVE.
-- ============================================================================
SELECT wallet_number, balance, status
FROM wallets
WHERE wallet_number IN (
    'P3W0000001',
    'P3W0000002',
    'P3W0000003'
)
ORDER BY wallet_number;


-- ============================================================================
-- SECTION S2-C (step 5): Start the transaction and request the wallet locks
-- (as shown in P3_23 and P3_27)
-- Run after Session 1 has locked its wallets (S1-B).
-- This query WAITS: Session 1 holds the row lock on P3W0000001. pgAdmin shows
-- "Waiting for the query to complete..." (P3_23). Leave it running.
-- While it waits, Session 1's blocking query (S1-C) shows this session as
-- active, wait_event_type Lock, blocked_by Session 1's PID.
-- After Session 1 commits (step 9) it finishes on its own.
-- Recorded result after the wait (P3_27): wallet 5009 P3W0000001 1,000.00
-- (the committed balance, not the 9,000.00 seen before Session 1 committed)
-- and wallet 5011 P3W0000003 0.00.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT
    wallet_id,
    wallet_number,
    balance,
    status
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000003')
ORDER BY wallet_id
FOR UPDATE;


-- ============================================================================
-- SECTION S2-D (step 11): Validation-only attempt P3-CONC-002
-- (as shown in P3_28)
-- Reads the sender balance with FOR UPDATE (this session already holds the
-- lock from S2-C). The exception is not caught. Recorded error:
--   ERROR:  Transfer P3-CONC-002 rejected: insufficient funds.
--           Available: 1000.00, required: 8000.00
--   CONTEXT:  PL/pgSQL function inline_code_block line 11 at RAISE
--   SQL state: P0001
-- No transaction row or ledger entry is written by this section.
-- ============================================================================
DO $$
DECLARE
    v_balance NUMERIC(18,2);
BEGIN
    SELECT balance INTO STRICT v_balance
    FROM wallets
    WHERE wallet_number = 'P3W0000001'
    FOR UPDATE;

    IF v_balance < 8000.00 THEN
        RAISE EXCEPTION
            'Transfer P3-CONC-002 rejected: insufficient funds. Available: %, required: 8000.00',
            v_balance;
    END IF;
END $$;


-- ============================================================================
-- SECTION S2-E (step 12): ROLLBACK — run on its own after the S2-D error
-- Ends the aborted transaction and releases Session 2's row locks.
-- The ROLLBACK message was not captured as a screenshot. The later outputs
-- are consistent with it: P3W0000003 still has 0.00 and no ledger entries
-- (P3_30), and no P3-CONC-002 transaction exists (P3_32).
-- ============================================================================
ROLLBACK;
