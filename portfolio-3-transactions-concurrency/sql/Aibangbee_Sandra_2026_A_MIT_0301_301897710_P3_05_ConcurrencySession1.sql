-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_05_ConcurrencySession1.sql
-- Description:  DEMONSTRATION 3 — Concurrent spending from one wallet.
--               SESSION 1: locks P3W0000001 and P3W0000002, shows that
--               Session 2 is blocked, transfers NGN 8,000.00 as
--               'P3-CONC-001' and commits.
--
-- SCENARIO (Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_CaseStudy.md, Business Problem):
--   A customer starts two transfers of 8,000.00 at the same time. Only one
--   may succeed; the other must be rejected for insufficient funds.
--   Session 1 (this file) spends from P3W0000001 to P3W0000002.
--   Session 2 (p3_06) tries to spend from P3W0000001 to P3W0000003 and must
--   wait for Session 1's row lock. The observer (p3_07) checks what other
--   sessions can see before and after Session 1 commits.
--
-- OPENING BALANCES (committed, after Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_04_Rollback.sql; checked in Session 2):
--   P3W0000001 = 9,000.00   P3W0000002 = 1,000.00   P3W0000003 = 0.00
--
-- RECORDED EVIDENCE (historical only, never used in the SQL below):
--   P3_SESSION_1 PID = 39364
--   P3_SESSION_2 PID = 41144
--   PIDs change with every new connection; each session reports its own PID
--   in its identify section.
--
-- TWO ATTEMPTS:
--   The locking test was run twice. In the first attempt, leftover pasted
--   text caused a syntax error in Session 1, which aborted Session 1's
--   transaction and released its locks. Both sessions were rolled back and
--   the test was repeated successfully. The screenshots include both
--   attempts (by their clock times, P3_22 and P3_23 come from the first
--   attempt), so no single lock-wait duration is reported.
--
-- SOURCE OF THE SQL TEXT:
--   Sections S1-A, S1-B and S1-C match the SQL visible in screenshots P3_19,
--   P3_22 and P3_24. In Section S1-D only the end of the DO block is visible
--   (P3_25); its earlier lines are a RECONSTRUCTION written to match the
--   recorded steps and are not an exact copy of the executed SQL.
--
-- ****************************************************************************
-- WARNING: P3-CONC-001 HAS ALREADY BEEN COMMITTED IN THE CURRENT DATABASE.
-- This file records the demonstration that was performed. Do NOT rerun
-- Sections S1-B to S1-E there. The validation in S1-D would now fail
-- (balance 1,000.00), and the reference is protected by
-- uq_transactions_reference.
-- ****************************************************************************
--
-- ****************************************************************************
-- HOW TO RUN: SEPARATE pgAdmin QUERY TOOL TABS, ONE PER FILE, SECTION BY
-- SECTION. NEVER RUN AN ENTIRE FILE AT ONCE. Highlight one section and
-- execute it. Each tab is a separate database session and must stay open
-- throughout.
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
-- SECTION S1-A (step 1): Identify this session (as shown in P3_19)
-- Recorded: korapay_wallet, session_id 39364, P3_SESSION_1, read committed.
-- ============================================================================
SET application_name = 'P3_SESSION_1';

SELECT
    current_database() AS database_name,
    pg_backend_pid() AS session_id,
    current_setting('application_name') AS session_name,
    current_setting('transaction_isolation') AS isolation_level;


-- ============================================================================
-- SECTION S1-B (step 4): Start the transaction and lock both wallets
-- (as shown in P3_22)
-- Rows are locked in ascending wallet_id order (Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_DatabaseDesign.md
-- Section 7.1). The query returns immediately because no other session holds
-- these rows. The locks are held until COMMIT (S1-E).
-- Recorded: wallet 5009 P3W0000001 9,000.00 and wallet 5010 P3W0000002
-- 1,000.00, both ACTIVE.
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT
    wallet_id,
    wallet_number,
    balance,
    status
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY wallet_id
FOR UPDATE;


-- ============================================================================
-- SECTION S1-C (step 6): Blocking query, run FROM SESSION 1
-- (as shown in P3_24)
-- Run after Session 2's S2-C lock request is waiting.
-- Recorded result:
--   39364  P3_SESSION_1  active  wait_event_type NULL, wait_event NULL,
--                        blocked_by {} (no blockers).
--   41144  P3_SESSION_2  active  wait_event_type Lock,
--                        blocked_by {39364}.
-- Session 1 appears as "active" because it is the session executing this
-- query. If the same query were run from an independent observer session,
-- Session 1 would normally appear as "idle in transaction" between its
-- statements, because it holds an open transaction without running a query.
-- ============================================================================
SELECT
    pid,
    application_name,
    state,
    wait_event_type,
    wait_event,
    pg_blocking_pids(pid) AS blocked_by
FROM pg_stat_activity
WHERE application_name IN ('P3_SESSION_1', 'P3_SESSION_2')
ORDER BY application_name;


-- ============================================================================
-- SECTION S1-D (step 7): Validate and post P3-CONC-001 in ONE DO block
-- *** ALREADY COMMITTED IN THE CURRENT DATABASE. DO NOT RERUN THERE. ***
-- The wallet locks from S1-B are still held. The block:
--   1. Reads both wallets into the record variables v_sender and
--      v_recipient, by wallet_number, with FOR UPDATE.
--   2. Validates that both wallets are ACTIVE CUSTOMER wallets in NGN.
--   3. Validates that the sender has at least 8,000.00.
--   4. Inserts P3-CONC-001 as a PENDING TRANSFER (no description).
--   5. Debits the sender and credits the recipient (updated_at set
--      explicitly); each UPDATE returns the new balance into a variable.
--   6. Inserts one DEBIT and one CREDIT, using those variables as
--      balance_after.
--   7. Marks the transaction SUCCESSFUL.
--   8. Raises the recorded NOTICE (P3_25):
--      P3-CONC-001 posted but NOT committed. Sender: 1000.00, recipient: 9000.00
-- The transaction is left OPEN. Other sessions still see 9,000.00 / 1,000.00
-- until COMMIT.
--
-- RECONSTRUCTED from DECLARE down to the recipient UPDATE's SET clause.
-- VERIFIED against P3_25 from "WHERE wallet_id = v_recipient.wallet_id"
-- to END $$.
-- ============================================================================
DO $$
DECLARE
    -- [Reconstructed] Declarations.
    v_sender          RECORD;
    v_recipient       RECORD;
    v_transaction_id  BIGINT;
    v_sender_after    NUMERIC(18,2);
    v_recipient_after NUMERIC(18,2);
BEGIN
    -- [Reconstructed] 1. Read and lock both wallets.
    SELECT wallet_id, wallet_type, currency, status, balance
    INTO STRICT v_sender
    FROM wallets
    WHERE wallet_number = 'P3W0000001'
    FOR UPDATE;

    SELECT wallet_id, wallet_type, currency, status, balance
    INTO STRICT v_recipient
    FROM wallets
    WHERE wallet_number = 'P3W0000002'
    FOR UPDATE;

    -- [Reconstructed] 2. Wallet validation.
    IF v_sender.wallet_type <> 'CUSTOMER'
       OR v_sender.currency <> 'NGN'
       OR v_sender.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Sender P3W0000001 is not an ACTIVE CUSTOMER NGN wallet.';
    END IF;

    IF v_recipient.wallet_type <> 'CUSTOMER'
       OR v_recipient.currency <> 'NGN'
       OR v_recipient.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Recipient P3W0000002 is not an ACTIVE CUSTOMER NGN wallet.';
    END IF;

    -- [Reconstructed] 3. Sufficient-funds validation.
    IF v_sender.balance < 8000.00 THEN
        RAISE EXCEPTION 'Insufficient funds for P3-CONC-001: available %, required 8000.00',
            v_sender.balance;
    END IF;

    -- [Reconstructed] 4. PENDING transaction.
    INSERT INTO transactions (
        reference, transaction_type,
        source_wallet_id, destination_wallet_id,
        amount, status
    )
    VALUES (
        'P3-CONC-001', 'TRANSFER',
        v_sender.wallet_id, v_recipient.wallet_id,
        8000.00, 'PENDING'
    )
    RETURNING transaction_id INTO v_transaction_id;

    -- [Reconstructed] 5. Balance updates.
    UPDATE wallets
    SET balance    = balance - 8000.00,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_sender.wallet_id
    RETURNING balance INTO v_sender_after;

    UPDATE wallets
    SET balance    = balance + 8000.00,
        updated_at = CURRENT_TIMESTAMP
    -- [Verified against P3_25 from the next line to END $$.]
    WHERE wallet_id = v_recipient.wallet_id
    RETURNING balance INTO v_recipient_after;

    INSERT INTO ledger_entries (
        transaction_id, wallet_id,
        entry_type, amount, balance_after
    )
    VALUES
        (v_transaction_id, v_sender.wallet_id,
         'DEBIT', 8000.00, v_sender_after),
        (v_transaction_id, v_recipient.wallet_id,
         'CREDIT', 8000.00, v_recipient_after);

    UPDATE transactions
    SET status = 'SUCCESSFUL'
    WHERE transaction_id = v_transaction_id;

    RAISE NOTICE
        'P3-CONC-001 posted but NOT committed. Sender: %, recipient: %',
        v_sender_after, v_recipient_after;
END $$;


-- ============================================================================
-- SECTION S1-E (step 9): COMMIT — run on its own
-- Run only after the observer has captured the before-commit check (O-A).
-- Committing releases the row locks; Session 2's waiting lock query (S2-C)
-- then finishes and returns the committed sender balance of 1,000.00.
-- The COMMIT message was not captured as a screenshot; its effect is shown
-- by P3_27 (Session 2 reads 1,000.00) and P3_29 (the observer sees the
-- committed transfer).
-- ============================================================================
COMMIT;
