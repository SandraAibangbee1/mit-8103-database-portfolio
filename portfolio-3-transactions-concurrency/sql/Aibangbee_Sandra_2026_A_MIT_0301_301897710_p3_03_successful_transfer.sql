-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_03_successful_transfer.sql
-- Description:  DEMONSTRATION 1 — Atomic successful wallet transfer.
--               Transfers NGN 1,000.00 from P3W0000001 to P3W0000002 as
--               TRANSFER 'P3-TRF-001' in one transaction.
--
-- WHAT THIS SCRIPT SHOWS:
--   The transaction record, both balance updates and the paired DEBIT and
--   CREDIT ledger entries are committed together. The script checks the
--   result before COMMIT and raises an exception on any mismatch, so either
--   everything is committed or nothing is.
--
-- WHAT THIS SCRIPT DOES NOT CHANGE:
--   Only wallets P3W0000001 and P3W0000002 are updated, and only one new
--   transaction (P3-TRF-001) and two ledger entries are added. No other
--   wallet, customer or existing transaction is modified. Only a
--   session-scoped TEMP table (ON COMMIT DROP) holds the baseline.
--
-- PREREQUISITE:
--   Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql has been committed (P3W0000001 = 10,000.00,
--   P3W0000002 = 0.00). This script runs once only: Stage 1 stops with an
--   exception if P3-TRF-001 already exists.
--
-- HOW TO RUN AND CAPTURE EVIDENCE (pgAdmin Query Tool, korapay_wallet):
--   pgAdmin shows only the LAST result grid when several statements run
--   together, so the evidence queries are run separately:
--   1. EVIDENCE A (before): highlight the Evidence A SELECT only and run it
--      (F5) to capture the opening balances 10,000.00 and 0.00.
--   2. TRANSFER: highlight from BEGIN; down to and including COMMIT; and run
--      it. The Messages tab shows the lock order and each stage's NOTICE.
--      If any error is reported, nothing has been saved; run ROLLBACK;
--      before running anything else in the same tab.
--   3. EVIDENCE B, C and D (after): highlight and run each SELECT on its own
--      to capture wallet balances, the transaction and its ledger entries.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- EVIDENCE A (run on its own BEFORE the transfer): opening balances
-- Expected: P3W0000001 10,000.00 and P3W0000002 0.00, both ACTIVE.
-- ----------------------------------------------------------------------------
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
-- TRANSFER: run from BEGIN; to COMMIT; as one block.
-- ============================================================================
BEGIN;

-- ----------------------------------------------------------------------------
-- STAGE 1: Guard checks
--   1a. P3-TRF-001 must not already exist (run-once).
--   1b. The P3 setup deposit P3-DEP-001 must exist and be SUCCESSFUL.
--   1c. Both wallets must exist.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    -- 1a. Run-once guard.
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-TRF-001';

    IF v_count > 0 THEN
        RAISE EXCEPTION 'Transaction P3-TRF-001 already exists. This demonstration runs once only.';
    END IF;

    -- 1b. Setup must have been committed.
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-DEP-001'
      AND status = 'SUCCESSFUL';

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'P3 setup deposit P3-DEP-001 was not found as SUCCESSFUL. Run p3_02_setup.sql first.';
    END IF;

    -- 1c. Both wallets exist.
    SELECT COUNT(*) INTO v_count
    FROM wallets
    WHERE wallet_number IN ('P3W0000001', 'P3W0000002');

    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Expected wallets P3W0000001 and P3W0000002, found % of them.', v_count;
    END IF;

    RAISE NOTICE 'Stage 1 passed: P3-TRF-001 is new and both wallets exist.';
END $$;

-- ----------------------------------------------------------------------------
-- STAGE 2: Baseline snapshot
-- Used in Stage 4 to prove that no other wallet, customer or existing
-- transaction was changed. "Other wallets" means every wallet except the
-- sender and the recipient, including SYSTEM_CLEARING and Portfolio 2 wallets.
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE p3_baseline ON COMMIT DROP AS
SELECT
    (SELECT COUNT(*) FROM customers)                               AS customer_count,
    (SELECT COUNT(*) FROM wallets)                                 AS wallet_count,
    (SELECT COUNT(*) FROM transactions)                            AS transaction_count,
    (SELECT COUNT(*) FROM ledger_entries)                          AS ledger_entry_count,
    (SELECT COALESCE(SUM(balance), 0.00) FROM wallets
     WHERE wallet_number NOT IN ('P3W0000001', 'P3W0000002'))      AS other_wallet_balance_total,
    (SELECT MAX(updated_at) FROM wallets
     WHERE wallet_number NOT IN ('P3W0000001', 'P3W0000002'))      AS other_wallet_last_update,
    (SELECT COUNT(*) FROM transactions
     WHERE status = 'SUCCESSFUL')                                  AS successful_transaction_count,
    (SELECT COUNT(*) FROM transactions
     WHERE status = 'PENDING')                                     AS pending_transaction_count;

-- ----------------------------------------------------------------------------
-- STAGE 3: Atomic transfer of NGN 1,000.00 from P3W0000001 to P3W0000002
-- Follows the posting flow in database-design.md Section 7:
--   3a. Claim the reference with a PENDING TRANSFER.
--   3b. Lock both wallets in ascending wallet_id order (SELECT ... FOR UPDATE).
--   3c. Validate both wallets while the locks are held: ACTIVE CUSTOMER NGN
--       wallets, opening balances 10,000.00 and 0.00, sufficient funds.
--   3d. Debit the sender and credit the recipient; set updated_at.
--   3e. Write one DEBIT (sender, money out) and one CREDIT (recipient,
--       money in) with balance_after taken from the updated balances.
--   3f. Mark the transaction SUCCESSFUL.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    c_amount            CONSTANT NUMERIC(18,2) := 1000.00;
    c_reference         CONSTANT VARCHAR(64)   := 'P3-TRF-001';
    c_sender_opening    CONSTANT NUMERIC(18,2) := 10000.00;
    c_recipient_opening CONSTANT NUMERIC(18,2) := 0.00;
    v_sender_id         BIGINT;
    v_recipient_id      BIGINT;
    v_sender_after      NUMERIC(18,2);
    v_recipient_after   NUMERIC(18,2);
    v_transaction_id    BIGINT;
    s                   RECORD;
    r                   RECORD;
    lk                  RECORD;
BEGIN
    -- Look up both wallet IDs dynamically.
    SELECT wallet_id INTO STRICT v_sender_id
    FROM wallets
    WHERE wallet_number = 'P3W0000001';

    SELECT wallet_id INTO STRICT v_recipient_id
    FROM wallets
    WHERE wallet_number = 'P3W0000002';

    -- 3a. Claim the reference.
    INSERT INTO transactions
        (reference, transaction_type, source_wallet_id, destination_wallet_id,
         amount, status, description)
    VALUES
        (c_reference, 'TRANSFER', v_sender_id, v_recipient_id,
         c_amount, 'PENDING', 'P3 demonstration 1: atomic successful transfer')
    RETURNING transaction_id INTO v_transaction_id;

    -- 3b. Lock both wallets in ascending wallet_id order. The loop reports
    --     the order in which the row locks were taken.
    FOR lk IN
        SELECT wallet_id, wallet_number
        FROM wallets
        WHERE wallet_id IN (v_sender_id, v_recipient_id)
        ORDER BY wallet_id ASC
        FOR UPDATE
    LOOP
        RAISE NOTICE 'Locked wallet_id % (%).', lk.wallet_id, lk.wallet_number;
    END LOOP;

    -- 3c. Validate while the locks are held.
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

    -- 3d. Debit the sender and credit the recipient.
    UPDATE wallets
    SET balance    = balance - c_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_sender_id
    RETURNING balance INTO v_sender_after;

    UPDATE wallets
    SET balance    = balance + c_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_recipient_id
    RETURNING balance INTO v_recipient_after;

    -- 3e. One balanced DEBIT and CREDIT pair.
    INSERT INTO ledger_entries
        (transaction_id, wallet_id, entry_type, amount, balance_after)
    VALUES
        (v_transaction_id, v_sender_id,    'DEBIT',  c_amount, v_sender_after),
        (v_transaction_id, v_recipient_id, 'CREDIT', c_amount, v_recipient_after);

    -- 3f. Complete the transaction.
    UPDATE transactions
    SET status = 'SUCCESSFUL'
    WHERE transaction_id = v_transaction_id;

    RAISE NOTICE 'Stage 3 posted % (transaction id %): P3W0000001 balance %, P3W0000002 balance %.',
        c_reference, v_transaction_id, v_sender_after, v_recipient_after;
END $$;

-- ----------------------------------------------------------------------------
-- STAGE 4: Validation before COMMIT
-- Any failure raises an exception, which aborts the transaction so that the
-- COMMIT below performs a rollback and nothing is saved.
--   V1. Row counts: customers and wallets unchanged, +1 transaction,
--       +2 ledger entries.
--   V2. P3-TRF-001 is a SUCCESSFUL TRANSFER of 1,000.00 from P3W0000001
--       to P3W0000002.
--   V3. It has exactly one matching DEBIT and one matching CREDIT.
--   V4. Final balances: P3W0000001 9,000.00 and P3W0000002 1,000.00.
--   V5. Both wallets reconcile with their ledger entries.
--   V6. No other wallet or existing transaction was changed.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    c_amount       CONSTANT NUMERIC(18,2) := 1000.00;
    c_sender_final CONSTANT NUMERIC(18,2) := 9000.00;
    c_recip_final  CONSTANT NUMERIC(18,2) := 1000.00;
    b              RECORD;
    t              RECORD;
    v_sender_id    BIGINT;
    v_recipient_id BIGINT;
    v_count        BIGINT;
    v_amount       NUMERIC(18,2);
    v_last         TIMESTAMPTZ;
BEGIN
    SELECT * INTO STRICT b FROM p3_baseline;

    SELECT wallet_id INTO STRICT v_sender_id
    FROM wallets
    WHERE wallet_number = 'P3W0000001';

    SELECT wallet_id INTO STRICT v_recipient_id
    FROM wallets
    WHERE wallet_number = 'P3W0000002';

    -- V1. Row count deltas.
    SELECT COUNT(*) INTO v_count FROM customers;
    IF v_count <> b.customer_count THEN
        RAISE EXCEPTION 'V1 failed: expected % customers, found %.', b.customer_count, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM wallets;
    IF v_count <> b.wallet_count THEN
        RAISE EXCEPTION 'V1 failed: expected % wallets, found %.', b.wallet_count, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM transactions;
    IF v_count <> b.transaction_count + 1 THEN
        RAISE EXCEPTION 'V1 failed: expected % transactions, found %.', b.transaction_count + 1, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM ledger_entries;
    IF v_count <> b.ledger_entry_count + 2 THEN
        RAISE EXCEPTION 'V1 failed: expected % ledger entries, found %.', b.ledger_entry_count + 2, v_count;
    END IF;

    -- V2. Transfer transaction.
    SELECT * INTO STRICT t
    FROM transactions
    WHERE reference = 'P3-TRF-001';

    IF t.transaction_type <> 'TRANSFER'
       OR t.status <> 'SUCCESSFUL'
       OR t.amount <> c_amount
       OR t.source_wallet_id <> v_sender_id
       OR t.destination_wallet_id <> v_recipient_id
       OR t.reversal_of_transaction_id IS NOT NULL THEN
        RAISE EXCEPTION 'V2 failed: P3-TRF-001 is % / % / % from % to %.',
            t.transaction_type, t.status, t.amount, t.source_wallet_id, t.destination_wallet_id;
    END IF;

    -- V3. Exactly one matching DEBIT and one matching CREDIT.
    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE transaction_id = t.transaction_id;

    IF v_count <> 2 THEN
        RAISE EXCEPTION 'V3 failed: expected 2 ledger entries for P3-TRF-001, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE transaction_id = t.transaction_id
      AND entry_type     = 'DEBIT'
      AND wallet_id      = v_sender_id
      AND amount         = c_amount
      AND balance_after  = c_sender_final;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'V3 failed: P3W0000001 DEBIT entry is missing or incorrect.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE transaction_id = t.transaction_id
      AND entry_type     = 'CREDIT'
      AND wallet_id      = v_recipient_id
      AND amount         = c_amount
      AND balance_after  = c_recip_final;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'V3 failed: P3W0000002 CREDIT entry is missing or incorrect.';
    END IF;

    -- V4. Final cached balances.
    SELECT balance INTO STRICT v_amount FROM wallets WHERE wallet_id = v_sender_id;
    IF v_amount <> c_sender_final THEN
        RAISE EXCEPTION 'V4 failed: P3W0000001 balance expected %, found %.', c_sender_final, v_amount;
    END IF;

    SELECT balance INTO STRICT v_amount FROM wallets WHERE wallet_id = v_recipient_id;
    IF v_amount <> c_recip_final THEN
        RAISE EXCEPTION 'V4 failed: P3W0000002 balance expected %, found %.', c_recip_final, v_amount;
    END IF;

    -- V5. Reconciliation for both wallets
    --     (CREDIT adds, DEBIT subtracts; wallets without entries count as 0.00).
    SELECT COUNT(*) INTO v_count
    FROM wallets AS w
    LEFT JOIN (
        SELECT
            le.wallet_id,
            SUM(CASE le.entry_type
                    WHEN 'CREDIT' THEN  le.amount
                    WHEN 'DEBIT'  THEN -le.amount
                END) AS ledger_total
        FROM ledger_entries AS le
        WHERE le.wallet_id IN (v_sender_id, v_recipient_id)
        GROUP BY le.wallet_id
    ) AS lm
        ON lm.wallet_id = w.wallet_id
    WHERE w.wallet_id IN (v_sender_id, v_recipient_id)
      AND w.balance <> COALESCE(lm.ledger_total, 0.00);

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'V5 failed: % wallet(s) do not reconcile with the ledger.', v_count;
    END IF;

    -- V6. No other wallet or existing transaction changed.
    SELECT COALESCE(SUM(balance), 0.00), MAX(updated_at) INTO v_amount, v_last
    FROM wallets
    WHERE wallet_id NOT IN (v_sender_id, v_recipient_id);

    IF v_amount <> b.other_wallet_balance_total
       OR v_last IS DISTINCT FROM b.other_wallet_last_update THEN
        RAISE EXCEPTION 'V6 failed: a wallet other than P3W0000001 and P3W0000002 was changed.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference <> 'P3-TRF-001'
      AND status = 'SUCCESSFUL';

    IF v_count <> b.successful_transaction_count THEN
        RAISE EXCEPTION 'V6 failed: existing SUCCESSFUL transactions changed (% -> %).',
            b.successful_transaction_count, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference <> 'P3-TRF-001'
      AND status = 'PENDING';

    IF v_count <> b.pending_transaction_count THEN
        RAISE EXCEPTION 'V6 failed: existing PENDING transactions changed (% -> %).',
            b.pending_transaction_count, v_count;
    END IF;

    RAISE NOTICE 'Stage 4 passed: all validation checks succeeded.';
END $$;

COMMIT;
-- ============================================================================
-- End of TRANSFER block.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- EVIDENCE B (run on its own AFTER COMMIT): wallet balances and reconciliation
-- Expected: P3W0000001 9,000.00 and P3W0000002 1,000.00, reconciled = true.
-- ----------------------------------------------------------------------------
SELECT
    w.wallet_number,
    w.status,
    w.balance                                                    AS cached_balance,
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
    w.status,
    w.balance,
    w.updated_at
ORDER BY w.wallet_number;


-- ----------------------------------------------------------------------------
-- EVIDENCE C (run on its own AFTER COMMIT): transaction details
-- Expected: one SUCCESSFUL TRANSFER of 1,000.00, P3W0000001 -> P3W0000002.
-- ----------------------------------------------------------------------------
SELECT
    t.transaction_id,
    t.reference,
    t.transaction_type,
    sw.wallet_number   AS source_wallet,
    dw.wallet_number   AS destination_wallet,
    t.amount,
    t.status,
    t.description,
    t.created_at
FROM transactions AS t
JOIN wallets AS sw
    ON sw.wallet_id = t.source_wallet_id
JOIN wallets AS dw
    ON dw.wallet_id = t.destination_wallet_id
WHERE t.reference = 'P3-TRF-001';


-- ----------------------------------------------------------------------------
-- EVIDENCE D (run on its own AFTER COMMIT): the two ledger entries
-- Expected: DEBIT 1,000.00 on P3W0000001 (balance_after 9,000.00) and
-- CREDIT 1,000.00 on P3W0000002 (balance_after 1,000.00).
-- ----------------------------------------------------------------------------
SELECT
    le.ledger_entry_id,
    t.reference,
    w.wallet_number,
    le.entry_type,
    le.amount,
    le.balance_after,
    le.created_at
FROM ledger_entries AS le
JOIN transactions AS t
    ON t.transaction_id = le.transaction_id
JOIN wallets AS w
    ON w.wallet_id = le.wallet_id
WHERE t.reference = 'P3-TRF-001'
ORDER BY le.entry_type DESC, le.ledger_entry_id;
