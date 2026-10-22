-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_04_rollback.sql
-- Description:  DEMONSTRATION 2 — Rollback after a deliberate failure.
--               A NGN 1,000.00 transfer from P3W0000001 to P3W0000002 with
--               reference 'P3-FAIL-001' debits the sender, then fails before
--               the recipient is credited. ROLLBACK discards every change.
--
-- SCENARIO (case-study.md, Business Problem):
--   "If an error occurs after debiting the sender but before crediting the
--   recipient, the entire transfer must roll back."
--   The failure is a simulated posting fault: a second DEBIT for the same
--   transaction, which violates uq_ledger_entries_txn_entry_type.
--
-- PREREQUISITE (committed state after Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_03_successful_transfer.sql):
--   P3W0000001 = 9,000.00 and P3W0000002 = 1,000.00.
--
-- WHAT THIS SCRIPT DOES NOT CHANGE:
--   This file contains no COMMIT. Every change made in Section B is undone
--   by the ROLLBACK in Section E, so no record in any table is modified.
--
-- ****************************************************************************
-- HOW TO RUN: SECTION BY SECTION, IN ONE QUERY TOOL TAB. DO NOT PRESS F5 ON
-- THE WHOLE FILE.
--   * Highlight one section at a time (A, B, C, D, E, F) and execute it.
--   * Use the SAME Query Tool tab throughout. A pgAdmin Query Tool tab is one
--     database session; the open transaction from Section B exists only in
--     that session. A new tab would not see the uncommitted changes.
--   * Running the whole file at once would stop at the Section D error and
--     skip the evidence sections, so the demonstration would be lost.
--   * pgAdmin option "Auto rollback on error" (Query Tool toolbar /
--     Preferences > Query Tool > Options): if it is ON, pgAdmin rolls back
--     automatically after the Section D error and Section E then reports
--     "WARNING: there is no transaction in progress". Turn it OFF for this
--     demonstration so the aborted state and the explicit ROLLBACK are shown.
-- ****************************************************************************
--
-- EVIDENCE TO CAPTURE:
--   A  -> opening balances 9,000.00 / 1,000.00 (committed state)
--   B  -> Messages tab: lock order, PENDING transaction id, temporary debit
--   C  -> temporary debit (8,000.00) and PENDING P3-FAIL-001 inside the
--         open transaction
--   D  -> ERROR 23505 duplicate key ... uq_ledger_entries_txn_entry_type
--         (optional: re-run Section C now to show "current transaction is
--         aborted, commands ignored until end of transaction block")
--   E  -> ROLLBACK
--   F1 -> balances back to 9,000.00 / 1,000.00, both wallets reconciled
--   F2 -> P3-FAIL-001 does not exist and has no ledger entries
-- ============================================================================


-- ============================================================================
-- SECTION A: Opening balances (read-only, committed state)
-- Expected: P3W0000001 9,000.00 and P3W0000002 1,000.00, both ACTIVE.
-- ============================================================================
SELECT
    w.wallet_id,
    w.wallet_number,
    w.wallet_type,
    w.currency,
    w.status,
    w.balance,
    w.updated_at
FROM wallets AS w
WHERE w.wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY w.wallet_number;


-- ============================================================================
-- SECTION B: Start the transfer and leave the transaction OPEN
--   B1. Guard: P3-FAIL-001 must not already exist.
--   B2. Look up both wallet IDs dynamically.
--   B3. Lock both wallets in ascending wallet_id order (SELECT ... FOR UPDATE).
--   B4. Validate: ACTIVE CUSTOMER NGN wallets, opening balances 9,000.00 and
--       1,000.00, sufficient funds.
--   B5. Insert the PENDING TRANSFER.
--   B6. Debit the sender (set updated_at) and insert its DEBIT ledger entry.
-- The recipient is NOT credited and there is NO COMMIT.
-- If this section raises an error, the transaction is aborted: run
-- Section E (ROLLBACK) before trying again.
-- ============================================================================
BEGIN;

DO $$
DECLARE
    c_amount            CONSTANT NUMERIC(18,2) := 1000.00;
    c_reference         CONSTANT VARCHAR(64)   := 'P3-FAIL-001';
    c_sender_opening    CONSTANT NUMERIC(18,2) := 9000.00;
    c_recipient_opening CONSTANT NUMERIC(18,2) := 1000.00;
    v_count             BIGINT;
    v_sender_id         BIGINT;
    v_recipient_id      BIGINT;
    v_sender_after      NUMERIC(18,2);
    v_transaction_id    BIGINT;
    s                   RECORD;
    r                   RECORD;
    lk                  RECORD;
BEGIN
    -- B1. Guard against an existing reference.
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = c_reference;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'Transaction % already exists. It must not exist for this demonstration.', c_reference;
    END IF;

    -- B2. Look up both wallet IDs dynamically.
    SELECT wallet_id INTO STRICT v_sender_id
    FROM wallets
    WHERE wallet_number = 'P3W0000001';

    SELECT wallet_id INTO STRICT v_recipient_id
    FROM wallets
    WHERE wallet_number = 'P3W0000002';

    -- B3. Lock both wallets in ascending wallet_id order.
    FOR lk IN
        SELECT wallet_id, wallet_number
        FROM wallets
        WHERE wallet_id IN (v_sender_id, v_recipient_id)
        ORDER BY wallet_id ASC
        FOR UPDATE
    LOOP
        RAISE NOTICE 'Locked wallet_id % (%).', lk.wallet_id, lk.wallet_number;
    END LOOP;

    -- B4. Validate while the locks are held.
    SELECT wallet_type, currency, status, balance INTO STRICT s
    FROM wallets
    WHERE wallet_id = v_sender_id;

    SELECT wallet_type, currency, status, balance INTO STRICT r
    FROM wallets
    WHERE wallet_id = v_recipient_id;

    IF s.wallet_type <> 'CUSTOMER' OR s.currency <> 'NGN' OR s.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Sender P3W0000001 must be an ACTIVE CUSTOMER NGN wallet (found %, %, %).',
            s.wallet_type, s.currency, s.status;
    END IF;

    IF r.wallet_type <> 'CUSTOMER' OR r.currency <> 'NGN' OR r.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Recipient P3W0000002 must be an ACTIVE CUSTOMER NGN wallet (found %, %, %).',
            r.wallet_type, r.currency, r.status;
    END IF;

    IF s.balance <> c_sender_opening OR r.balance <> c_recipient_opening THEN
        RAISE EXCEPTION 'Unexpected opening balances: sender % (expected %), recipient % (expected %).',
            s.balance, c_sender_opening, r.balance, c_recipient_opening;
    END IF;

    IF s.balance < c_amount THEN
        RAISE EXCEPTION 'Insufficient funds: sender balance %, transfer amount %.',
            s.balance, c_amount;
    END IF;

    -- B5. Insert the PENDING transaction.
    INSERT INTO transactions
        (reference, transaction_type, source_wallet_id, destination_wallet_id,
         amount, status, description)
    VALUES
        (c_reference, 'TRANSFER', v_sender_id, v_recipient_id,
         c_amount, 'PENDING', 'P3 demonstration 2: transfer rolled back after failure')
    RETURNING transaction_id INTO v_transaction_id;

    -- B6. Debit the sender and write its DEBIT entry. No credit yet.
    UPDATE wallets
    SET balance    = balance - c_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_sender_id
    RETURNING balance INTO v_sender_after;

    INSERT INTO ledger_entries
        (transaction_id, wallet_id, entry_type, amount, balance_after)
    VALUES
        (v_transaction_id, v_sender_id, 'DEBIT', c_amount, v_sender_after);

    RAISE NOTICE 'Section B: % (transaction id %) is PENDING; P3W0000001 debited to % (uncommitted). Transaction left open.',
        c_reference, v_transaction_id, v_sender_after;
END $$;


-- ============================================================================
-- SECTION C: Evidence inside the open transaction (read-only, same tab)
-- Shows the uncommitted state visible only to this session.
-- Expected: P3-FAIL-001 PENDING, sender balance 8,000.00 (temporary),
-- recipient balance 1,000.00 (not yet credited), 1 DEBIT and 0 CREDIT entries.
-- ============================================================================
SELECT
    t.transaction_id,
    t.reference,
    t.transaction_type,
    t.status,
    t.amount,
    sw.wallet_number                                             AS sender_wallet,
    sw.balance                                                   AS sender_balance_uncommitted,
    dw.wallet_number                                             AS recipient_wallet,
    dw.balance                                                   AS recipient_balance,
    (SELECT COUNT(*) FROM ledger_entries AS le
     WHERE le.transaction_id = t.transaction_id
       AND le.entry_type = 'DEBIT')                              AS debit_entries,
    (SELECT COUNT(*) FROM ledger_entries AS le
     WHERE le.transaction_id = t.transaction_id
       AND le.entry_type = 'CREDIT')                             AS credit_entries,
    (SELECT le.balance_after FROM ledger_entries AS le
     WHERE le.transaction_id = t.transaction_id
       AND le.entry_type = 'DEBIT')                              AS debit_balance_after
FROM transactions AS t
JOIN wallets AS sw
    ON sw.wallet_id = t.source_wallet_id
JOIN wallets AS dw
    ON dw.wallet_id = t.destination_wallet_id
WHERE t.reference = 'P3-FAIL-001';


-- ============================================================================
-- SECTION D: Deliberate failure (same tab, transaction still open)
-- Simulates a posting fault after the sender was debited and before the
-- recipient is credited: a second DEBIT for the same transaction.
-- The exception is NOT caught. Expected error:
--   ERROR:  duplicate key value violates unique constraint
--           "uq_ledger_entries_txn_entry_type"
--   DETAIL: Key (transaction_id, entry_type)=(<id>, DEBIT) already exists.
--   SQLSTATE: 23505
-- PostgreSQL now marks the whole transaction as aborted. Optionally re-run
-- Section C to show: "current transaction is aborted, commands ignored until
-- end of transaction block".
-- ============================================================================
INSERT INTO ledger_entries
    (transaction_id, wallet_id, entry_type, amount, balance_after)
SELECT
    t.transaction_id,
    t.source_wallet_id,
    'DEBIT',
    t.amount,
    w.balance - t.amount
FROM transactions AS t
JOIN wallets AS w
    ON w.wallet_id = t.source_wallet_id
WHERE t.reference = 'P3-FAIL-001';


-- ============================================================================
-- SECTION E: ROLLBACK (run on its own, after the Section D error)
-- Discards the PENDING transaction, the sender debit and the DEBIT ledger
-- entry, and releases both wallet row locks.
-- ============================================================================
ROLLBACK;


-- ============================================================================
-- SECTION F1: Balances and reconciliation after ROLLBACK (read-only)
-- Expected: P3W0000001 9,000.00 and P3W0000002 1,000.00, matching the
-- opening balances, reconciled = true, and ledger entry counts unchanged
-- (P3W0000001: 2 — setup CREDIT and P3-TRF-001 DEBIT; P3W0000002: 1 —
-- P3-TRF-001 CREDIT).
-- ============================================================================
SELECT
    w.wallet_number,
    w.balance                                                    AS cached_balance,
    CASE w.wallet_number
        WHEN 'P3W0000001' THEN 9000.00
        WHEN 'P3W0000002' THEN 1000.00
    END                                                          AS expected_balance,
    COALESCE(SUM(CASE le.entry_type
                     WHEN 'CREDIT' THEN  le.amount
                     WHEN 'DEBIT'  THEN -le.amount
                 END), 0.00)                                     AS ledger_total,
    COUNT(le.ledger_entry_id)                                    AS ledger_entry_count,
    w.balance = COALESCE(SUM(CASE le.entry_type
                                 WHEN 'CREDIT' THEN  le.amount
                                 WHEN 'DEBIT'  THEN -le.amount
                             END), 0.00)                         AS reconciled,
    w.updated_at
FROM wallets AS w
LEFT JOIN ledger_entries AS le
    ON le.wallet_id = w.wallet_id
WHERE w.wallet_number IN ('P3W0000001', 'P3W0000002')
GROUP BY
    w.wallet_id,
    w.wallet_number,
    w.balance,
    w.updated_at
ORDER BY w.wallet_number;


-- ============================================================================
-- SECTION F2: P3-FAIL-001 left no trace (read-only)
-- Expected: fail_transaction_count = 0 and fail_ledger_entry_count = 0.
-- Because ledger_entries.transaction_id is a foreign key to transactions,
-- no ledger entry can exist for a transaction that does not exist; the
-- second count confirms this directly.
-- ============================================================================
SELECT
    (SELECT COUNT(*)
     FROM transactions
     WHERE reference = 'P3-FAIL-001')                            AS fail_transaction_count,
    (SELECT COUNT(*)
     FROM ledger_entries AS le
     JOIN transactions AS t
         ON t.transaction_id = le.transaction_id
     WHERE t.reference = 'P3-FAIL-001')                          AS fail_ledger_entry_count;
