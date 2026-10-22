-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_08_duplicate_reference.sql
-- Description:  DEMONSTRATION 4 — Duplicate request reference rejected.
--               Attempts to insert a second transaction that reuses the
--               committed reference 'P3-CONC-001'. The UNIQUE constraint
--               uq_transactions_reference rejects it, so a repeated request
--               cannot create a second transfer.
--
-- THIS FILE RECORDS AN ALREADY COMPLETED TEST.
--   The SQL below is written to match the recorded steps. The test ends with
--   ROLLBACK, so it changed no data.
--
-- PREREQUISITE:
--   P3-CONC-001 has been committed (Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_05_concurrency_session1.sql).
--
-- ****************************************************************************
-- HOW TO RUN: SECTION BY SECTION, IN ONE pgAdmin QUERY TOOL TAB.
-- NEVER RUN THE ENTIRE FILE AT ONCE. Highlight one section and execute it.
--   Section A  BEGIN and the duplicate INSERT -> expected error 23505.
--   Section B  ROLLBACK (run on its own after the error).
--   Section C  Read-only verification.
-- If pgAdmin "Auto rollback on error" is ON, pgAdmin rolls back after the
-- Section A error and Section B reports "there is no transaction in progress".
-- ****************************************************************************
--
-- RECORDED FINAL RESULT (Section C):
--   Only P3-CONC-001 exists: amount 8000.00, status SUCCESSFUL, 2 ledger
--   entries. P3-CONC-002 has no saved transaction.
-- ============================================================================


-- ============================================================================
-- SECTION A: Attempt to reuse the reference P3-CONC-001
-- Copies reference, transaction_type, source_wallet_id, destination_wallet_id
-- and amount from the existing P3-CONC-001 row, with status 'PENDING'.
-- Expected error (not caught):
--   ERROR:  duplicate key value violates unique constraint
--           "uq_transactions_reference"
--   DETAIL: Key (reference)=(P3-CONC-001) already exists.
--   SQLSTATE: 23505
-- The transaction is now aborted; run Section B next.
-- ============================================================================
BEGIN;

INSERT INTO transactions
    (reference, transaction_type, source_wallet_id, destination_wallet_id,
     amount, status)
SELECT
    t.reference,
    t.transaction_type,
    t.source_wallet_id,
    t.destination_wallet_id,
    t.amount,
    'PENDING'
FROM transactions AS t
WHERE t.reference = 'P3-CONC-001';


-- ============================================================================
-- SECTION B: ROLLBACK (run on its own, after the Section A error)
-- Ends the aborted transaction. Nothing from Section A is saved.
-- ============================================================================
ROLLBACK;


-- ============================================================================
-- SECTION C: Verification (read-only)
-- Recorded result: one row only —
--   P3-CONC-001  8000.00  SUCCESSFUL  ledger_entry_count 2
-- P3-CONC-002 does not appear because it has no saved transaction.
-- ============================================================================
SELECT
    t.reference,
    t.amount,
    t.status,
    COUNT(le.ledger_entry_id)                     AS ledger_entry_count
FROM transactions AS t
LEFT JOIN ledger_entries AS le
    ON le.transaction_id = t.transaction_id
WHERE t.reference IN ('P3-CONC-001', 'P3-CONC-002')
GROUP BY
    t.transaction_id,
    t.reference,
    t.amount,
    t.status
ORDER BY t.reference;
