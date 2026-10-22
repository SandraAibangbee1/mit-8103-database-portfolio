-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_12_savepoint_demo.sql
-- Description:  SAVEPOINT RECOVERY DEMONSTRATION using
--               public.korapay_transfer_funds (..._p3_09_transfer_function.sql).
--
-- WHAT THIS DEMONSTRATION DOES (one transaction):
--   1. Records the opening balances of P3W0000001 and P3W0000002.
--   2. BEGIN; transfers 1.00 from P3W0000001 to P3W0000002 (P3-SAVE-001).
--   3. SAVEPOINT before_second_transfer.
--   4. Attempts a 1,000,000.00 transfer (P3-SAVE-FAIL-001). The function
--      raises "insufficient funds" (SQLSTATE P0001) and the transaction
--      enters the aborted state.
--   5. psql checks that this exact expected error occurred, then
--      ROLLBACK TO SAVEPOINT before_second_transfer recovers the transaction.
--   6. Shows that P3-SAVE-001 is still present inside the transaction, while
--      P3-SAVE-FAIL-001 and any ledger entries for it do not exist.
--   7. COMMIT keeps the first transfer.
--   8. Verifies one SUCCESSFUL P3-SAVE-001 with its DEBIT/CREDIT pair, and
--      reconciles both wallets.
--
-- HOW THE FAILURE IS HANDLED:
--   The failing call is a real, uncaught error: there is no DO-block
--   exception handler around it. ON_ERROR_STOP is switched off for that one
--   statement only, so psql continues and records the error in its
--   ERROR, SQLSTATE, LAST_ERROR_SQLSTATE and LAST_ERROR_MESSAGE variables.
--   ON_ERROR_STOP is switched back on immediately afterwards. If the error is
--   not exactly the expected one, the script raises an assertion error and
--   stops; the open transaction is then discarded when psql disconnects.
--   ON_ERROR_ROLLBACK is set off so psql does not create hidden savepoints of
--   its own: the only recovery is the explicit ROLLBACK TO SAVEPOINT.
--
-- ****************************************************************************
-- THIS DEMONSTRATION PERMANENTLY TRANSFERS ANOTHER NGN 1.00 FROM P3W0000001
-- TO P3W0000002. If the opening balances are still 999.00 and 9,001.00, the
-- expected final balances are 998.00 and 9,002.00. Balances are NOT reset
-- and P3-SAVE-001 is kept as evidence.
-- ****************************************************************************
--
-- RUN ONCE ONLY:
--   The pre-check stops the script before any change if P3-SAVE-001 or
--   P3-SAVE-FAIL-001 already exists.
--
-- HOW TO RUN (psql 12 or later, for LAST_ERROR_SQLSTATE and
-- LAST_ERROR_MESSAGE; not the pgAdmin Query Tool; pgAdmin's PSQL Tool works):
--   psql -h localhost -U postgres -d korapay_wallet -f Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_12_savepoint_demo.sql
-- ============================================================================

\set ON_ERROR_STOP on
\set ON_ERROR_ROLLBACK off
\pset null '(null)'

\echo '=== P3 SAVEPOINT recovery demonstration ==='
\echo '*** This demonstration permanently transfers 1.00 from P3W0000001 to P3W0000002 ***'


-- ----------------------------------------------------------------------------
-- PRE-CHECKS (read-only, before any change)
-- Stops the script if either reference is already used, the function is
-- missing or a wallet is missing. Saves the opening balances as session
-- settings for the assertion blocks.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference IN ('P3-SAVE-001', 'P3-SAVE-FAIL-001');
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'PRE-CHECK FAILED: P3-SAVE-001 or P3-SAVE-FAIL-001 already exists (% row(s)). Nothing was changed.', v_count;
    END IF;

    IF to_regprocedure('public.korapay_transfer_funds(varchar, varchar, numeric, varchar)') IS NULL THEN
        RAISE EXCEPTION 'PRE-CHECK FAILED: public.korapay_transfer_funds is not installed.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM wallets
    WHERE wallet_number IN ('P3W0000001', 'P3W0000002');
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'PRE-CHECK FAILED: expected wallets P3W0000001 and P3W0000002, found %.', v_count;
    END IF;

    PERFORM set_config('p3test.open_sender',
        (SELECT balance::TEXT FROM wallets WHERE wallet_number = 'P3W0000001'), false);
    PERFORM set_config('p3test.open_recipient',
        (SELECT balance::TEXT FROM wallets WHERE wallet_number = 'P3W0000002'), false);

    RAISE NOTICE 'Pre-checks passed. Opening balances: P3W0000001 %, P3W0000002 %.',
        current_setting('p3test.open_sender'), current_setting('p3test.open_recipient');
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
-- STEP 2: BEGIN and the first (successful) transfer, P3-SAVE-001
-- ----------------------------------------------------------------------------
\echo '--- Step 2: BEGIN and first transfer (P3-SAVE-001) ---'
BEGIN;

SELECT public.korapay_transfer_funds(
    'P3W0000001', 'P3W0000002', 1.00, 'P3-SAVE-001'
) AS transaction_id \gset first_

SELECT set_config('p3test.save_id', :'first_transaction_id', false) AS save_id_saved \gset

\echo 'P3-SAVE-001 transaction_id:' :first_transaction_id


-- ----------------------------------------------------------------------------
-- STEP 3: SAVEPOINT
-- ----------------------------------------------------------------------------
\echo '--- Step 3: SAVEPOINT before_second_transfer ---'
SAVEPOINT before_second_transfer;


-- ----------------------------------------------------------------------------
-- STEP 4: Deliberately failing transfer, P3-SAVE-FAIL-001
-- Expected error (not caught by any handler):
--   ERROR:  Transfer rejected: insufficient funds in wallet P3W0000001.
--           Available: <opening - 1.00>, required: 1000000.00.
--   SQLSTATE: P0001
-- ON_ERROR_STOP is off for this ONE statement only. The error result is
-- copied straight away, because the next successful command resets
-- ERROR and SQLSTATE.
-- ----------------------------------------------------------------------------
\echo '--- Step 4: deliberately failing transfer (P3-SAVE-FAIL-001) ---'
\set ON_ERROR_STOP off
SELECT public.korapay_transfer_funds(
    'P3W0000001', 'P3W0000002', 1000000.00, 'P3-SAVE-FAIL-001'
);
\set fail_error :ERROR
\set fail_sqlstate :SQLSTATE
\set ON_ERROR_STOP on

\echo 'Failed statement: ERROR =' :fail_error ', SQLSTATE =' :fail_sqlstate


-- ----------------------------------------------------------------------------
-- STEP 5: Recover with ROLLBACK TO SAVEPOINT, then verify the error
-- ROLLBACK TO SAVEPOINT ends the aborted state and discards everything done
-- after the savepoint (the PENDING claim of P3-SAVE-FAIL-001), but keeps
-- P3-SAVE-001. LAST_ERROR_SQLSTATE and LAST_ERROR_MESSAGE still hold the
-- details of the deliberate failure, because no other error has occurred.
-- ----------------------------------------------------------------------------
\echo '--- Step 5: ROLLBACK TO SAVEPOINT before_second_transfer ---'
ROLLBACK TO SAVEPOINT before_second_transfer;

\echo '--- Step 5: was the failure exactly the expected one? ---'
SELECT
    :'fail_error'          AS statement_failed,
    :'fail_sqlstate'       AS statement_sqlstate,
    :'LAST_ERROR_SQLSTATE' AS last_error_sqlstate,
    :'LAST_ERROR_MESSAGE'  AS last_error_message,
    (
        :'fail_error' = 'true'
        AND :'fail_sqlstate' = 'P0001'
        AND :'LAST_ERROR_SQLSTATE' = 'P0001'
        AND :'LAST_ERROR_MESSAGE' = format(
            'Transfer rejected: insufficient funds in wallet P3W0000001. Available: %s, required: 1000000.00.',
            (current_setting('p3test.open_sender')::NUMERIC(18,2) - 1.00)::NUMERIC(18,2)
        )
    )                      AS expected_failure
\gset

\if :expected_failure
    \echo 'PASS: the deliberate transfer failed with the expected insufficient-funds error (SQLSTATE P0001).'
\else
    \echo 'UNEXPECTED: the deliberate transfer did not fail with the expected error.'
    \echo 'ERROR =' :fail_error ', SQLSTATE =' :fail_sqlstate
    \echo 'LAST_ERROR_MESSAGE =' :LAST_ERROR_MESSAGE
    DO $$ BEGIN RAISE EXCEPTION 'ASSERTION FAILED: unexpected result from the deliberately failing transfer. Stopping without commit.'; END $$;
\endif


-- ----------------------------------------------------------------------------
-- STEP 6: State inside the transaction after recovery
-- ----------------------------------------------------------------------------
\echo '--- Step 6: transactions for both references (inside the transaction) ---'
SELECT
    r.reference,
    t.transaction_id,
    t.status,
    t.amount,
    (SELECT COUNT(*) FROM ledger_entries AS le
     WHERE le.transaction_id = t.transaction_id) AS ledger_entry_count
FROM (VALUES ('P3-SAVE-001'), ('P3-SAVE-FAIL-001')) AS r (reference)
LEFT JOIN transactions AS t
    ON t.reference = r.reference
ORDER BY r.reference;

\echo '--- Step 6: balances inside the transaction ---'
SELECT wallet_number, balance
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY wallet_number;

\echo '--- Step 6: assertions inside the transaction ---'
DO $$
DECLARE
    v_save_id     BIGINT        := current_setting('p3test.save_id')::BIGINT;
    v_open_sender NUMERIC(18,2) := current_setting('p3test.open_sender')::NUMERIC;
    v_open_recip  NUMERIC(18,2) := current_setting('p3test.open_recipient')::NUMERIC;
    v_count       BIGINT;
    v_balance     NUMERIC(18,2);
BEGIN
    -- The first transfer is still present and SUCCESSFUL.
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-SAVE-001'
      AND transaction_id = v_save_id
      AND status = 'SUCCESSFUL'
      AND amount = 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3-SAVE-001 is not present as a SUCCESSFUL 1.00 transfer.';
    END IF;

    SELECT COUNT(*) INTO v_count FROM ledger_entries WHERE transaction_id = v_save_id;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3-SAVE-001 has % ledger entries (expected 2).', v_count;
    END IF;

    -- The failed transfer and any ledger entries for it do not exist.
    SELECT COUNT(*) INTO v_count FROM transactions WHERE reference = 'P3-SAVE-FAIL-001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: % transaction row(s) exist for P3-SAVE-FAIL-001.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN transactions AS t ON t.transaction_id = le.transaction_id
    WHERE t.reference = 'P3-SAVE-FAIL-001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: % ledger row(s) exist for P3-SAVE-FAIL-001.', v_count;
    END IF;

    -- Only the first transfer has moved money.
    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000001';
    IF v_balance <> v_open_sender - 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000001 balance % (expected %).', v_balance, v_open_sender - 1.00;
    END IF;

    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000002';
    IF v_balance <> v_open_recip + 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000002 balance % (expected %).', v_balance, v_open_recip + 1.00;
    END IF;

    RAISE NOTICE 'PASS: after ROLLBACK TO SAVEPOINT, P3-SAVE-001 remains; P3-SAVE-FAIL-001 left no transaction or ledger rows.';
END $$;


-- ----------------------------------------------------------------------------
-- STEP 7: COMMIT the retained first transfer
-- ----------------------------------------------------------------------------
\echo '--- Step 7: COMMIT ---'
COMMIT;


-- ----------------------------------------------------------------------------
-- STEP 8: Committed results
-- ----------------------------------------------------------------------------
\echo '--- Step 8: committed transaction for P3-SAVE-001 ---'
SELECT
    t.transaction_id,
    t.reference,
    t.transaction_type,
    sw.wallet_number AS source_wallet,
    dw.wallet_number AS destination_wallet,
    t.amount,
    t.status
FROM transactions AS t
JOIN wallets AS sw ON sw.wallet_id = t.source_wallet_id
JOIN wallets AS dw ON dw.wallet_id = t.destination_wallet_id
WHERE t.reference IN ('P3-SAVE-001', 'P3-SAVE-FAIL-001')
ORDER BY t.reference;

\echo '--- Step 8: ledger entries for P3-SAVE-001 ---'
SELECT
    le.ledger_entry_id,
    w.wallet_number,
    le.entry_type,
    le.amount,
    le.balance_after
FROM ledger_entries AS le
JOIN transactions AS t ON t.transaction_id = le.transaction_id
JOIN wallets AS w ON w.wallet_id = le.wallet_id
WHERE t.reference = 'P3-SAVE-001'
ORDER BY le.entry_type DESC, le.ledger_entry_id;

\echo '--- Step 8: ledger reconciliation ---'
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
WHERE w.wallet_number IN ('P3W0000001', 'P3W0000002')
GROUP BY w.wallet_id, w.wallet_number, w.balance
ORDER BY w.wallet_number;

\echo '--- Step 8: assertions after COMMIT ---'
DO $$
DECLARE
    v_save_id     BIGINT        := current_setting('p3test.save_id')::BIGINT;
    v_open_sender NUMERIC(18,2) := current_setting('p3test.open_sender')::NUMERIC;
    v_open_recip  NUMERIC(18,2) := current_setting('p3test.open_recipient')::NUMERIC;
    v_count       BIGINT;
    v_balance     NUMERIC(18,2);
BEGIN
    -- Exactly one SUCCESSFUL P3-SAVE-001 transfer of 1.00, P3W0000001 -> P3W0000002.
    SELECT COUNT(*) INTO v_count FROM transactions WHERE reference = 'P3-SAVE-001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected 1 P3-SAVE-001 transaction, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions AS t
    JOIN wallets AS sw ON sw.wallet_id = t.source_wallet_id
    JOIN wallets AS dw ON dw.wallet_id = t.destination_wallet_id
    WHERE t.reference = 'P3-SAVE-001'
      AND t.transaction_id = v_save_id
      AND t.transaction_type = 'TRANSFER'
      AND t.status = 'SUCCESSFUL'
      AND t.amount = 1.00
      AND sw.wallet_number = 'P3W0000001'
      AND dw.wallet_number = 'P3W0000002';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3-SAVE-001 is not the expected SUCCESSFUL transfer.';
    END IF;

    -- Its DEBIT/CREDIT pair, with balance_after matching one 1.00 movement.
    SELECT COUNT(*) INTO v_count FROM ledger_entries WHERE transaction_id = v_save_id;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3-SAVE-001 has % ledger entries (expected 2).', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN wallets AS w ON w.wallet_id = le.wallet_id
    WHERE le.transaction_id = v_save_id
      AND le.entry_type = 'DEBIT'
      AND w.wallet_number = 'P3W0000001'
      AND le.amount = 1.00
      AND le.balance_after = v_open_sender - 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected one DEBIT of 1.00 on P3W0000001 with balance_after %.', v_open_sender - 1.00;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN wallets AS w ON w.wallet_id = le.wallet_id
    WHERE le.transaction_id = v_save_id
      AND le.entry_type = 'CREDIT'
      AND w.wallet_number = 'P3W0000002'
      AND le.amount = 1.00
      AND le.balance_after = v_open_recip + 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected one CREDIT of 1.00 on P3W0000002 with balance_after %.', v_open_recip + 1.00;
    END IF;

    -- The failed reference was never saved.
    SELECT COUNT(*) INTO v_count FROM transactions WHERE reference = 'P3-SAVE-FAIL-001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3-SAVE-FAIL-001 exists after COMMIT.';
    END IF;

    -- Balances moved by 1.00 once.
    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000001';
    IF v_balance <> v_open_sender - 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000001 balance % (expected %).', v_balance, v_open_sender - 1.00;
    END IF;

    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000002';
    IF v_balance <> v_open_recip + 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000002 balance % (expected %).', v_balance, v_open_recip + 1.00;
    END IF;

    -- Both wallets reconcile with their ledger entries.
    SELECT COUNT(*) INTO v_count
    FROM wallets AS w
    LEFT JOIN (
        SELECT le.wallet_id,
               SUM(CASE le.entry_type
                       WHEN 'CREDIT' THEN  le.amount
                       WHEN 'DEBIT'  THEN -le.amount
                   END) AS ledger_total
        FROM ledger_entries AS le
        JOIN wallets AS lw ON lw.wallet_id = le.wallet_id
        WHERE lw.wallet_number IN ('P3W0000001', 'P3W0000002')
        GROUP BY le.wallet_id
    ) AS lm ON lm.wallet_id = w.wallet_id
    WHERE w.wallet_number IN ('P3W0000001', 'P3W0000002')
      AND w.balance <> COALESCE(lm.ledger_total, 0.00);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: % wallet(s) do not reconcile with the ledger.', v_count;
    END IF;

    RAISE NOTICE 'PASS: P3-SAVE-001 committed once with its DEBIT/CREDIT pair; P3-SAVE-FAIL-001 absent; both wallets reconcile.';
END $$;

\echo '=== SAVEPOINT demonstration completed: all assertions passed ==='
\echo '*** P3-SAVE-001 (1.00) remains committed as evidence ***'
