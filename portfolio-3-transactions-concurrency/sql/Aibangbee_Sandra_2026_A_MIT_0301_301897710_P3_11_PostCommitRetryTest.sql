-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_11_PostCommitRetryTest.sql
-- Description:  POST-COMMIT RETRY TEST for public.korapay_transfer_funds
--               (installed by ..._P3_09_TransferFunction.sql).
--
-- WHAT THIS TEST DOES:
--   1. Records the opening balances of P3W0000001 and P3W0000002.
--   2. Transaction 1: transfers 1.00 from P3W0000001 to P3W0000002 with
--      reference P3-FUNC-COMMIT-001, and COMMITS.
--   3. Transaction 2: retries the identical request (same wallets, amount and
--      reference) in a NEW transaction, and COMMITS.
--   4. Asserts that both calls returned the same transaction_id, that only
--      one SUCCESSFUL transaction and one DEBIT/CREDIT pair exist for the
--      reference, and that the balances changed by 1.00 only once.
--   5. Shows ledger reconciliation for both wallets.
--
-- WHAT THIS TEST IS NOT:
--   It is not a concurrent retry test: the retry starts only after the first
--   transaction has committed.
--
-- ****************************************************************************
-- THIS TEST PERMANENTLY TRANSFERS NGN 1.00 FROM P3W0000001 TO P3W0000002.
-- If the opening balances are still 1,000.00 and 9,000.00, the expected final
-- balances are 999.00 and 9,001.00. Balances are NOT reset afterwards and
-- the P3-FUNC-COMMIT-001 transaction and its ledger entries are kept as
-- evidence.
-- ****************************************************************************
--
-- RUN ONCE ONLY:
--   The pre-check stops the script before anything is changed if the
--   reference P3-FUNC-COMMIT-001 already exists.
--
-- HOW TO RUN (psql, not the pgAdmin Query Tool, because it uses psql
-- meta-commands such as \gset and \echo; pgAdmin's PSQL Tool also works):
--   psql -h localhost -U postgres -d korapay_wallet -f Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_11_PostCommitRetryTest.sql
--
-- FAILURE BEHAVIOUR:
--   ON_ERROR_STOP is on, so any unexpected error or failed assertion stops
--   psql with a non-zero exit status. An error inside an open transaction
--   means that transaction is not committed. A failed assertion AFTER the
--   commits does not undo the committed transfer; it reports the problem.
-- ============================================================================

\set ON_ERROR_STOP on
\pset null '(null)'

\echo '=== P3 post-commit retry test for public.korapay_transfer_funds ==='
\echo '*** This test permanently transfers 1.00 from P3W0000001 to P3W0000002 ***'


-- ----------------------------------------------------------------------------
-- PRE-CHECKS (read-only, before any change)
-- Stops the script if the function is missing, a wallet is missing, or the
-- reference already exists. Saves the opening balances as session settings
-- so the assertion blocks can compare against them across transactions.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-FUNC-COMMIT-001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'PRE-CHECK FAILED: reference P3-FUNC-COMMIT-001 already exists (% row(s)). Nothing was changed.', v_count;
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
-- STEP 2: Transaction 1 — first call, then COMMIT
-- The returned ID is captured as :first_transaction_id and also saved as a
-- session setting, which survives the COMMIT for the assertion block.
-- ----------------------------------------------------------------------------
\echo '--- Step 2: transaction 1 (first call) ---'
BEGIN;

SELECT public.korapay_transfer_funds(
    'P3W0000001', 'P3W0000002', 1.00, 'P3-FUNC-COMMIT-001'
) AS transaction_id \gset first_

SELECT set_config('p3test.first_id', :'first_transaction_id', false) AS first_id_saved \gset

COMMIT;

\echo 'First call returned (committed):' :first_transaction_id

\echo '--- Balances after transaction 1 ---'
SELECT wallet_number, balance
FROM wallets
WHERE wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY wallet_number;


-- ----------------------------------------------------------------------------
-- STEP 3: Transaction 2 — identical retry in a NEW transaction, then COMMIT
-- The function's reference claim finds the committed P3-FUNC-COMMIT-001 row,
-- confirms the request is identical and SUCCESSFUL, and returns the original
-- transaction_id without moving money again.
-- ----------------------------------------------------------------------------
\echo '--- Step 3: transaction 2 (identical retry) ---'
BEGIN;

SELECT public.korapay_transfer_funds(
    'P3W0000001', 'P3W0000002', 1.00, 'P3-FUNC-COMMIT-001'
) AS transaction_id \gset second_

SELECT set_config('p3test.second_id', :'second_transaction_id', false) AS second_id_saved \gset

COMMIT;

\echo 'Retry returned (committed):    ' :second_transaction_id


-- ----------------------------------------------------------------------------
-- STEP 4: Results after both commits
-- ----------------------------------------------------------------------------
\echo '--- Step 4: returned IDs ---'
SELECT
    :first_transaction_id::BIGINT                                  AS first_call_id,
    :second_transaction_id::BIGINT                                 AS retry_call_id,
    :first_transaction_id::BIGINT = :second_transaction_id::BIGINT AS ids_match;

\echo '--- Step 4: transaction rows for P3-FUNC-COMMIT-001 ---'
SELECT
    t.transaction_id,
    t.reference,
    t.transaction_type,
    t.amount,
    t.status,
    t.created_at
FROM transactions AS t
WHERE t.reference = 'P3-FUNC-COMMIT-001';

\echo '--- Step 4: ledger entries for P3-FUNC-COMMIT-001 ---'
SELECT
    le.ledger_entry_id,
    w.wallet_number,
    le.entry_type,
    le.amount,
    le.balance_after
FROM ledger_entries AS le
JOIN transactions AS t
    ON t.transaction_id = le.transaction_id
JOIN wallets AS w
    ON w.wallet_id = le.wallet_id
WHERE t.reference = 'P3-FUNC-COMMIT-001'
ORDER BY le.entry_type DESC, le.ledger_entry_id;

\echo '--- Step 4: final balances against opening balances ---'
SELECT
    w.wallet_number,
    CASE w.wallet_number
        WHEN 'P3W0000001' THEN current_setting('p3test.open_sender')::NUMERIC(18,2)
        WHEN 'P3W0000002' THEN current_setting('p3test.open_recipient')::NUMERIC(18,2)
    END                                         AS opening_balance,
    w.balance                                   AS final_balance,
    w.balance - CASE w.wallet_number
        WHEN 'P3W0000001' THEN current_setting('p3test.open_sender')::NUMERIC(18,2)
        WHEN 'P3W0000002' THEN current_setting('p3test.open_recipient')::NUMERIC(18,2)
    END                                         AS change
FROM wallets AS w
WHERE w.wallet_number IN ('P3W0000001', 'P3W0000002')
ORDER BY w.wallet_number;


-- ----------------------------------------------------------------------------
-- STEP 5: Ledger reconciliation for both wallets
-- CREDIT adds to the ledger total, DEBIT subtracts.
-- ----------------------------------------------------------------------------
\echo '--- Step 5: ledger reconciliation ---'
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


-- ----------------------------------------------------------------------------
-- STEP 6: Assertions (after both commits)
-- ----------------------------------------------------------------------------
\echo '--- Step 6: assertions ---'
DO $$
DECLARE
    v_first_id    BIGINT        := current_setting('p3test.first_id')::BIGINT;
    v_second_id   BIGINT        := current_setting('p3test.second_id')::BIGINT;
    v_open_sender NUMERIC(18,2) := current_setting('p3test.open_sender')::NUMERIC;
    v_open_recip  NUMERIC(18,2) := current_setting('p3test.open_recipient')::NUMERIC;
    v_count       BIGINT;
    v_balance     NUMERIC(18,2);
BEGIN
    -- A1. Both calls returned the same transaction_id.
    IF v_first_id IS DISTINCT FROM v_second_id THEN
        RAISE EXCEPTION 'ASSERTION FAILED: IDs differ (first %, retry %).', v_first_id, v_second_id;
    END IF;

    -- A2. Exactly one transaction for the reference: the returned SUCCESSFUL
    --     TRANSFER of 1.00 from P3W0000001 to P3W0000002.
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference = 'P3-FUNC-COMMIT-001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected 1 transaction for the reference, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions AS t
    JOIN wallets AS sw ON sw.wallet_id = t.source_wallet_id
    JOIN wallets AS dw ON dw.wallet_id = t.destination_wallet_id
    WHERE t.reference = 'P3-FUNC-COMMIT-001'
      AND t.transaction_id = v_first_id
      AND t.transaction_type = 'TRANSFER'
      AND t.status = 'SUCCESSFUL'
      AND t.amount = 1.00
      AND sw.wallet_number = 'P3W0000001'
      AND dw.wallet_number = 'P3W0000002';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: the transaction is not the returned SUCCESSFUL TRANSFER of 1.00 from P3W0000001 to P3W0000002.';
    END IF;

    -- A3. Exactly one DEBIT/CREDIT pair, with balance_after matching the
    --     single 1.00 movement.
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
      AND le.amount = 1.00
      AND le.balance_after = v_open_sender - 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected one DEBIT of 1.00 on P3W0000001 with balance_after %.', v_open_sender - 1.00;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN wallets AS w ON w.wallet_id = le.wallet_id
    WHERE le.transaction_id = v_first_id
      AND le.entry_type = 'CREDIT'
      AND w.wallet_number = 'P3W0000002'
      AND le.amount = 1.00
      AND le.balance_after = v_open_recip + 1.00;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected one CREDIT of 1.00 on P3W0000002 with balance_after %.', v_open_recip + 1.00;
    END IF;

    -- A4. Balances changed by 1.00 only once.
    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000001';
    IF v_balance <> v_open_sender - 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000001 balance % (expected %).', v_balance, v_open_sender - 1.00;
    END IF;

    SELECT balance INTO STRICT v_balance FROM wallets WHERE wallet_number = 'P3W0000002';
    IF v_balance <> v_open_recip + 1.00 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: P3W0000002 balance % (expected %).', v_balance, v_open_recip + 1.00;
    END IF;

    -- A5. Both wallets reconcile with their ledger entries.
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

    RAISE NOTICE 'PASS: retry returned the same ID (%), 1 SUCCESSFUL transaction, 1 DEBIT + 1 CREDIT, balances moved by 1.00 once, both wallets reconcile.',
        v_first_id;
END $$;

\echo '=== Post-commit retry test completed: all assertions passed ==='
\echo '*** P3-FUNC-COMMIT-001 (1.00) remains committed as evidence ***'
