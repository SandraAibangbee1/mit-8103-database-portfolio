-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_10_FunctionRetryTest.sql
-- Description:  SAME-TRANSACTION RETRY TEST for public.korapay_transfer_funds
--               (installed by ..._P3_09_TransferFunction.sql).
--
-- WHAT THIS TEST DOES:
--   Inside ONE transaction it calls the function twice with identical
--   arguments (P3W0000001 -> P3W0000002, 1.00, reference P3-FUNC-RETRY-001)
--   and checks that:
--     * both calls return the same transaction_id;
--     * exactly one SUCCESSFUL transaction exists for the reference;
--     * exactly two ledger entries exist: one DEBIT and one CREDIT;
--     * the balances moved by 1.00 once, not twice.
--   It then ROLLS BACK, so no money moves permanently, and checks that the
--   opening balances are restored and no rows remain for the reference.
--
-- WHAT THIS TEST IS NOT:
--   It is NOT a concurrent retry test (two sessions at the same time) and NOT
--   a post-commit retry test (a retry after the first call was committed).
--   The second call sees the first call's uncommitted row only because both
--   run in the same transaction.
--
-- HOW TO RUN (psql, not the pgAdmin Query Tool, because it uses psql
-- meta-commands such as \gset and \echo; pgAdmin's PSQL Tool also works):
--   psql -h localhost -U postgres -d korapay_wallet -f Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_10_FunctionRetryTest.sql
--
-- FAILURE BEHAVIOUR:
--   ON_ERROR_STOP is on. Any unexpected error or failed assertion (raised as
--   an exception) stops psql immediately with a non-zero exit status. If that
--   happens while the transaction is open, nothing is committed: the open
--   transaction is rolled back when the psql connection closes.
--
-- NOTE: ROLLBACK does not return sequence values, so the transaction_id used
-- by this test will be skipped by later transactions.
-- ============================================================================

\set ON_ERROR_STOP on
\pset null '(null)'

\echo '=== P3 same-transaction retry test for public.korapay_transfer_funds ==='


-- ----------------------------------------------------------------------------
-- PRE-CHECKS (outside the transaction, read-only)
-- The function must exist, both wallets must exist, and the test reference
-- must not already be in use. Opening balances are saved as session
-- settings so the later assertion blocks can read them.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    IF to_regprocedure('public.korapay_transfer_funds(varchar, varchar, numeric, varchar)') IS NULL THEN
        RAISE EXCEPTION 'PRE-CHECK FAILED: public.korapay_transfer_funds is not installed.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM wallets
    WHERE wallet_number IN ('P3W0000001', 'P3W0000002');
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'PRE-CHECK FAILED: expected wallets P3W0000001 and P3W0000002, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-FUNC-RETRY-001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'PRE-CHECK FAILED: reference P3-FUNC-RETRY-001 already exists (% row(s)).', v_count;
    END IF;

    PERFORM set_config('p3test.open_sender',
        (SELECT balance::TEXT FROM wallets WHERE wallet_number = 'P3W0000001'), false);
    PERFORM set_config('p3test.open_recipient',
        (SELECT balance::TEXT FROM wallets WHERE wallet_number = 'P3W0000002'), false);

    RAISE NOTICE 'Pre-checks passed.';
END $$;


-- ----------------------------------------------------------------------------
-- STEP 1: Opening balances (committed state)
-- ----------------------------------------------------------------------------
\echo '--- Step 1: opening balances ---'
SELECT wallet_number, balance, status
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY wallet_number;


-- ----------------------------------------------------------------------------
-- STEP 2: Begin the test transaction
-- ----------------------------------------------------------------------------
\echo '--- Step 2: BEGIN ---'
BEGIN;


-- ----------------------------------------------------------------------------
-- STEP 3 and 4: Call the function twice with identical arguments.
-- Each returned ID is captured with \gset using a distinct prefix:
--   first call  -> :first_transaction_id
--   second call -> :second_transaction_id
-- The first call posts the transfer. The second call finds the reference
-- already claimed by this transaction's own SUCCESSFUL row and returns the
-- same transaction_id without moving money again.
-- ----------------------------------------------------------------------------
\echo '--- Step 3: first call ---'
SELECT public.korapay_transfer_funds(
    'P3W0000001', 'P3W0000002', 1.00, 'P3-FUNC-RETRY-001'
) AS transaction_id \gset first_

\echo '--- Step 3: second call (identical arguments) ---'
SELECT public.korapay_transfer_funds(
    'P3W0000001', 'P3W0000002', 1.00, 'P3-FUNC-RETRY-001'
) AS transaction_id \gset second_

\echo 'First call returned: ' :first_transaction_id
\echo 'Second call returned:' :second_transaction_id

-- Make the captured IDs available to the assertion block below
-- (transaction-local settings, discarded at ROLLBACK).
SELECT
    set_config('p3test.first_id',  :'first_transaction_id',  true) AS first_id_saved,
    set_config('p3test.second_id', :'second_transaction_id', true) AS second_id_saved
\gset


-- ----------------------------------------------------------------------------
-- STEP 5: Do the returned IDs match?
-- ----------------------------------------------------------------------------
\echo '--- Step 5: returned IDs ---'
SELECT
    :first_transaction_id::BIGINT                                AS first_call_id,
    :second_transaction_id::BIGINT                               AS second_call_id,
    :first_transaction_id::BIGINT = :second_transaction_id::BIGINT AS ids_match;


-- ----------------------------------------------------------------------------
-- STEP 6: Transactions and ledger entries for the reference (inside the
-- open transaction)
-- ----------------------------------------------------------------------------
\echo '--- Step 6: transaction rows for P3-FUNC-RETRY-001 ---'
SELECT
    COUNT(*)                                        AS transaction_count,
    string_agg(t.status, ', ')                      AS statuses,
    string_agg(t.amount::TEXT, ', ')                AS amounts
FROM transactions AS t
WHERE t.reference = 'P3-FUNC-RETRY-001';

\echo '--- Step 6: ledger entries for P3-FUNC-RETRY-001 ---'
SELECT
    le.ledger_entry_id,
    t.transaction_id,
    w.wallet_number,
    le.entry_type,
    le.amount,
    le.balance_after
FROM ledger_entries AS le
JOIN transactions AS t
    ON t.transaction_id = le.transaction_id
JOIN wallets AS w
    ON w.wallet_id = le.wallet_id
WHERE t.reference = 'P3-FUNC-RETRY-001'
ORDER BY le.entry_type DESC, le.ledger_entry_id;


-- ----------------------------------------------------------------------------
-- STEP 7: Balances inside the transaction (visible only to this session)
-- ----------------------------------------------------------------------------
\echo '--- Step 7: balances inside the transaction ---'
SELECT wallet_number, balance
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY wallet_number;


-- ----------------------------------------------------------------------------
-- ASSERTIONS (inside the transaction)
-- Any failed check raises an exception; ON_ERROR_STOP then stops psql and
-- the open transaction is discarded.
-- ----------------------------------------------------------------------------
\echo '--- Assertions inside the transaction ---'
DO $$
DECLARE
    v_first_id      BIGINT        := current_setting('p3test.first_id')::BIGINT;
    v_second_id     BIGINT        := current_setting('p3test.second_id')::BIGINT;
    v_open_sender   NUMERIC(18,2) := current_setting('p3test.open_sender')::NUMERIC;
    v_open_recip    NUMERIC(18,2) := current_setting('p3test.open_recipient')::NUMERIC;
    v_count         BIGINT;
    v_balance       NUMERIC(18,2);
BEGIN
    -- A1. Both calls returned the same transaction_id.
    IF v_first_id IS DISTINCT FROM v_second_id THEN
        RAISE EXCEPTION 'ASSERTION FAILED: IDs differ (first %, second %).', v_first_id, v_second_id;
    END IF;

    -- A2. Exactly one transaction for the reference, and it is the returned
    --     SUCCESSFUL TRANSFER of 1.00.
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-FUNC-RETRY-001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected 1 transaction for the reference, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-FUNC-RETRY-001'
      AND transaction_id = v_first_id
      AND transaction_type = 'TRANSFER'
      AND status = 'SUCCESSFUL'
      AND amount = 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: the transaction is not the returned SUCCESSFUL TRANSFER of 1.00.';
    END IF;

    -- A3. Exactly two ledger entries: one DEBIT on P3W0000001 and one CREDIT
    --     on P3W0000002, each 1.00.
    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE transaction_id = v_first_id;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected 2 ledger entries, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN wallets AS w ON w.wallet_id = le.wallet_id
    WHERE le.transaction_id = v_first_id
      AND le.entry_type = 'DEBIT'
      AND w.wallet_number = 'P3W0000001'
      AND le.amount = 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected one DEBIT of 1.00 on P3W0000001, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN wallets AS w ON w.wallet_id = le.wallet_id
    WHERE le.transaction_id = v_first_id
      AND le.entry_type = 'CREDIT'
      AND w.wallet_number = 'P3W0000002'
      AND le.amount = 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected one CREDIT of 1.00 on P3W0000002, found %.', v_count;
    END IF;

    -- A4. Money moved once, not twice.
    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000001';
    IF v_balance <> v_open_sender - 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000001 balance % (expected %).', v_balance, v_open_sender - 1.00;
    END IF;

    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000002';
    IF v_balance <> v_open_recip + 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000002 balance % (expected %).', v_balance, v_open_recip + 1.00;
    END IF;

    RAISE NOTICE 'PASS: same ID returned twice, 1 SUCCESSFUL transaction, 1 DEBIT + 1 CREDIT, money moved once.';
END $$;


-- ----------------------------------------------------------------------------
-- STEP 8: ROLLBACK — discard the test transfer
-- ----------------------------------------------------------------------------
\echo '--- Step 8: ROLLBACK ---'
ROLLBACK;


-- ----------------------------------------------------------------------------
-- STEP 9: Restored state (committed data)
-- ----------------------------------------------------------------------------
\echo '--- Step 9: balances after ROLLBACK ---'
SELECT wallet_number, balance
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY wallet_number;

\echo '--- Step 9: rows remaining for P3-FUNC-RETRY-001 ---'
SELECT
    (SELECT COUNT(*)
     FROM transactions
     WHERE reference = 'P3-FUNC-RETRY-001')                AS transaction_rows,
    (SELECT COUNT(*)
     FROM ledger_entries AS le
     JOIN transactions AS t ON t.transaction_id = le.transaction_id
     WHERE t.reference = 'P3-FUNC-RETRY-001')              AS ledger_rows_via_reference,
    (SELECT COUNT(*)
     FROM ledger_entries
     WHERE transaction_id = :first_transaction_id::BIGINT) AS ledger_rows_for_returned_id;

\echo '--- Assertions after ROLLBACK ---'
DO $$
DECLARE
    v_open_sender NUMERIC(18,2) := current_setting('p3test.open_sender')::NUMERIC;
    v_open_recip  NUMERIC(18,2) := current_setting('p3test.open_recipient')::NUMERIC;
    v_count       BIGINT;
    v_balance     NUMERIC(18,2);
BEGIN
    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000001';
    IF v_balance <> v_open_sender THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000001 balance % not restored to %.', v_balance, v_open_sender;
    END IF;

    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000002';
    IF v_balance <> v_open_recip THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000002 balance % not restored to %.', v_balance, v_open_recip;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-FUNC-RETRY-001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: % transaction row(s) remain for the reference.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN transactions AS t ON t.transaction_id = le.transaction_id
    WHERE t.reference = 'P3-FUNC-RETRY-001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: % ledger row(s) remain for the reference.', v_count;
    END IF;

    RAISE NOTICE 'PASS: balances restored; 0 transaction and 0 ledger rows for P3-FUNC-RETRY-001.';
END $$;

\echo '=== Same-transaction retry test completed: all assertions passed ==='
