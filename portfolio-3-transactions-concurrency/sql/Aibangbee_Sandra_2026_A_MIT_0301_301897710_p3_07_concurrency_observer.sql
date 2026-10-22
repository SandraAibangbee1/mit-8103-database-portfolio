-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_07_concurrency_observer.sql
-- Description:  DEMONSTRATION 3 — Concurrent spending from one wallet.
--               OBSERVER: read-only queries run from a third session, opened
--               after Session 1's posting, to show what other sessions can
--               see before and after Session 1 commits, and to reconcile
--               the result.
--
-- WHAT THIS SESSION DOES:
--   SELECT statements only (plus SET application_name). It never starts a
--   transaction block and changes no data, so its sections are safe to rerun.
--   The opening balances were checked in Session 2 (p3_06, S2-B), and the
--   blocking query was run from Session 1 (p3_05, S1-C), not from here.
--
-- SOURCE OF THE SQL TEXT:
--   O-A matches the SQL visible in P3_26 and P3_29. In O-B the first five
--   lines are not visible in P3_30; they are RECONSTRUCTED from the output
--   column names, and the rest matches the screenshot. O-C matches P3_32,
--   which was captured after the duplicate-reference test
--   (Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_08_duplicate_reference.sql, Section C uses the same query).
--
-- ****************************************************************************
-- WARNING: P3-CONC-001 HAS ALREADY BEEN COMMITTED IN THE CURRENT DATABASE.
-- Session 1's posting (p3_05, S1-D) must not be rerun there. In the current
-- database O-A shows the after-commit balances.
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
-- SECTION O-A (steps 8 and 13): Identify the observer and check visibility
-- (as shown in P3_26 and P3_29)
-- One query reports the session name, isolation level, both balances and
-- whether P3-CONC-001 is visible. Run twice:
--   Step 8  (before Session 1 commits, P3_26): P3_OBSERVER, read committed,
--           9,000.00 / 1,000.00, visible_transfer_count 0. Session 1's
--           uncommitted changes are not visible (no dirty read).
--   Step 13 (after Session 1 commits, P3_29):  1,000.00 / 9,000.00,
--           visible_transfer_count 1.
-- ============================================================================
SET application_name = 'P3_OBSERVER';

SELECT
    current_setting('application_name') AS session_name,
    current_setting('transaction_isolation') AS isolation_level,
    wallet_number,
    balance,
    (
        SELECT COUNT(*)
        FROM transactions
        WHERE reference = 'P3-CONC-001'
    ) AS visible_transfer_count
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY wallet_number;


-- ============================================================================
-- SECTION O-B (step 14): Reconciliation of all three P3 wallets
-- (as shown in P3_30; the first five lines are reconstructed)
-- CREDIT adds to the ledger total, DEBIT subtracts; wallets with no ledger
-- entries count as 0.00.
-- Recorded:
--   P3W0000001  1,000.00  ledger 1,000.00  3 entries  true
--   P3W0000002  9,000.00  ledger 9,000.00  2 entries  true
--   P3W0000003      0.00  ledger     0.00  0 entries  true
-- ============================================================================
SELECT
    w.wallet_number,
    w.balance AS cached_balance,
    COALESCE(SUM(
        CASE le.entry_type
            WHEN 'CREDIT' THEN le.amount
            WHEN 'DEBIT' THEN -le.amount
        END
    ), 0.00) AS ledger_total,
    COUNT(le.ledger_entry_id) AS ledger_entry_count,
    w.balance = COALESCE(SUM(
        CASE le.entry_type
            WHEN 'CREDIT' THEN le.amount
            WHEN 'DEBIT' THEN -le.amount
        END
    ), 0.00) AS reconciled
FROM wallets AS w
LEFT JOIN ledger_entries AS le
    ON le.wallet_id = w.wallet_id
WHERE w.wallet_number IN (
    'P3W0000001',
    'P3W0000002',
    'P3W0000003'
)
GROUP BY w.wallet_id, w.wallet_number, w.balance
ORDER BY w.wallet_number;


-- ============================================================================
-- SECTION O-C (step 15): Verification of the saved transfer
-- (as shown in P3_32, captured after the duplicate-reference test)
-- Recorded: one row only — P3-CONC-001, 8000.00, SUCCESSFUL,
-- ledger_entry_count 2. P3-CONC-002 does not appear because Session 2 was a
-- validation-only attempt that was rolled back.
-- ============================================================================
SELECT
    t.reference,
    t.amount,
    t.status,
    COUNT(le.ledger_entry_id) AS ledger_entry_count
FROM transactions AS t
LEFT JOIN ledger_entries AS le
    ON le.transaction_id = t.transaction_id
WHERE t.reference IN ('P3-CONC-001', 'P3-CONC-002')
GROUP BY t.transaction_id, t.reference, t.amount, t.status
ORDER BY t.reference;
