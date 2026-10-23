-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_17_benchmark_setup.sql
-- Description:  pgbench comparison, ORDERED versus UNORDERED lock acquisition.
--               Part 1 creates two lab transfer functions that differ ONLY
--               in the order they lock the two accounts (and the variant
--               label they log). Part 2 is a read-only integrity check.
--
-- SCOPE:
--   Only p3_lab.accounts and p3_lab.transfer_log. No KoraPay financial table
--   is used. Balances are not reset and existing log rows are not deleted.
--
-- OBSERVED BASELINE (before p3_17, reported by you):
--   20 accounts, SUM(balance) = 1801800.00, MIN(balance) = 800.00.
--
-- SAFE TO RE-RUN:
--   Part 1 uses CREATE OR REPLACE with the same definitions, and Part 2 only
--   reads. Re-running the whole file before and after each pgbench run
--   produces a fresh check log each time.
--
-- RUN ORDER (Command Prompt, from portfolio-3-transactions-concurrency):
--   set PSQL="C:\Program Files\PostgreSQL\18\bin\psql.exe"
--   set PGBENCH="C:\Program Files\PostgreSQL\18\bin\pgbench.exe"
--   set P=Aibangbee_Sandra_2026_A_MIT_0301_301897710_
--   1. %PSQL% -X -h localhost -U postgres -d korapay_wallet -v ON_ERROR_STOP=1 -a -f sql\%P%p3_17_benchmark_setup.sql > output\%P%p3_17_check_1_before.log 2>&1
--   2. %PGBENCH% -h localhost -U postgres -n -c 10 -j 4 -t 200 --max-tries=1 --failures-detailed -f sql\%P%p3_17_unordered_workload.sql korapay_wallet > output\%P%p3_17_pgbench_unordered.txt 2>&1
--   3. %PSQL% ... same as 1 ... > output\%P%p3_17_check_2_after_unordered.log 2>&1
--   4. %PGBENCH% ... same as 2 with %P%p3_17_ordered_workload.sql ... > output\%P%p3_17_pgbench_ordered.txt 2>&1
--   5. %PSQL% ... same as 1 ... > output\%P%p3_17_check_3_after_ordered.log 2>&1
--   (-n skips pgbench's own vacuum; --max-tries=1 means no automatic retries,
--    so deadlock failures stay visible; 10 clients x 200 = 2000 transactions.)
-- ============================================================================


-- ============================================================================
-- PART 1 — Lab transfer functions (one transaction)
-- ============================================================================
BEGIN;

-- Guard: the lab accounts must be exactly IDs 1-20. Nothing is reset.
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM p3_lab.accounts WHERE account_id BETWEEN 1 AND 20) <> 20
       OR (SELECT COUNT(*) FROM p3_lab.accounts) <> 20 THEN
        RAISE EXCEPTION 'p3_lab.accounts must contain exactly account_id 1-20.';
    END IF;
END $$;


-- UNORDERED: locks the SOURCE account first, then the DESTINATION.
-- Two transfers in opposite directions between the same accounts can each
-- hold one lock and wait for the other, which is a deadlock.
CREATE OR REPLACE FUNCTION p3_lab.transfer_unordered(
    p_from_account_id INTEGER,
    p_to_account_id   INTEGER,
    p_amount          NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = pg_catalog, p3_lab
AS $$
DECLARE
    v_amount       NUMERIC(18,2);
    v_first_id     INTEGER;
    v_second_id    INTEGER;
    v_from_balance NUMERIC(18,2);
    v_log_id       BIGINT;
BEGIN
    -- Argument validation.
    IF p_from_account_id IS NULL OR p_to_account_id IS NULL THEN
        RAISE EXCEPTION 'Lab transfer rejected: both account IDs are required.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_from_account_id = p_to_account_id THEN
        RAISE EXCEPTION 'Lab transfer rejected: accounts must be different.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_amount IS NULL
       OR p_amount IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
       OR p_amount <= 0
       OR p_amount <> round(p_amount, 2)
       OR p_amount > 9999999999999999.99 THEN
        RAISE EXCEPTION 'Lab transfer rejected: amount % must be positive, finite and have at most two decimals.', p_amount
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    v_amount := p_amount;

    -- LOCK ORDER (the only behavioural difference between the two functions).
    v_first_id  := p_from_account_id;
    v_second_id := p_to_account_id;

    PERFORM 1 FROM p3_lab.accounts WHERE account_id = v_first_id FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lab transfer rejected: account % does not exist.', v_first_id
            USING ERRCODE = 'no_data_found';
    END IF;

    PERFORM 1 FROM p3_lab.accounts WHERE account_id = v_second_id FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lab transfer rejected: account % does not exist.', v_second_id
            USING ERRCODE = 'no_data_found';
    END IF;

    -- Balance check after both locks are held.
    SELECT balance INTO STRICT v_from_balance
    FROM p3_lab.accounts
    WHERE account_id = p_from_account_id;

    IF v_from_balance < v_amount THEN
        RAISE EXCEPTION 'Lab transfer rejected: insufficient balance in account % (available %, required %).',
            p_from_account_id, v_from_balance, v_amount;
    END IF;

    -- Debit, credit and log in the caller's transaction.
    UPDATE p3_lab.accounts
    SET balance = balance - v_amount, updated_at = CURRENT_TIMESTAMP
    WHERE account_id = p_from_account_id;

    UPDATE p3_lab.accounts
    SET balance = balance + v_amount, updated_at = CURRENT_TIMESTAMP
    WHERE account_id = p_to_account_id;

    INSERT INTO p3_lab.transfer_log (variant, from_account_id, to_account_id, amount)
    VALUES ('UNORDERED', p_from_account_id, p_to_account_id, v_amount)
    RETURNING log_id INTO v_log_id;

    RETURN v_log_id;
END;
$$;


-- ORDERED: locks the SMALLER account_id first, then the LARGER.
-- Every transfer requests the same pair of rows in the same order, so two
-- transfers on the same pair wait for each other instead of deadlocking.
CREATE OR REPLACE FUNCTION p3_lab.transfer_ordered(
    p_from_account_id INTEGER,
    p_to_account_id   INTEGER,
    p_amount          NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = pg_catalog, p3_lab
AS $$
DECLARE
    v_amount       NUMERIC(18,2);
    v_first_id     INTEGER;
    v_second_id    INTEGER;
    v_from_balance NUMERIC(18,2);
    v_log_id       BIGINT;
BEGIN
    -- Argument validation.
    IF p_from_account_id IS NULL OR p_to_account_id IS NULL THEN
        RAISE EXCEPTION 'Lab transfer rejected: both account IDs are required.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_from_account_id = p_to_account_id THEN
        RAISE EXCEPTION 'Lab transfer rejected: accounts must be different.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_amount IS NULL
       OR p_amount IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
       OR p_amount <= 0
       OR p_amount <> round(p_amount, 2)
       OR p_amount > 9999999999999999.99 THEN
        RAISE EXCEPTION 'Lab transfer rejected: amount % must be positive, finite and have at most two decimals.', p_amount
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    v_amount := p_amount;

    -- LOCK ORDER (the only behavioural difference between the two functions).
    v_first_id  := LEAST(p_from_account_id, p_to_account_id);
    v_second_id := GREATEST(p_from_account_id, p_to_account_id);

    PERFORM 1 FROM p3_lab.accounts WHERE account_id = v_first_id FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lab transfer rejected: account % does not exist.', v_first_id
            USING ERRCODE = 'no_data_found';
    END IF;

    PERFORM 1 FROM p3_lab.accounts WHERE account_id = v_second_id FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lab transfer rejected: account % does not exist.', v_second_id
            USING ERRCODE = 'no_data_found';
    END IF;

    -- Balance check after both locks are held.
    SELECT balance INTO STRICT v_from_balance
    FROM p3_lab.accounts
    WHERE account_id = p_from_account_id;

    IF v_from_balance < v_amount THEN
        RAISE EXCEPTION 'Lab transfer rejected: insufficient balance in account % (available %, required %).',
            p_from_account_id, v_from_balance, v_amount;
    END IF;

    -- Debit, credit and log in the caller's transaction.
    UPDATE p3_lab.accounts
    SET balance = balance - v_amount, updated_at = CURRENT_TIMESTAMP
    WHERE account_id = p_from_account_id;

    UPDATE p3_lab.accounts
    SET balance = balance + v_amount, updated_at = CURRENT_TIMESTAMP
    WHERE account_id = p_to_account_id;

    INSERT INTO p3_lab.transfer_log (variant, from_account_id, to_account_id, amount)
    VALUES ('ORDERED', p_from_account_id, p_to_account_id, v_amount)
    RETURNING log_id INTO v_log_id;

    RETURN v_log_id;
END;
$$;

COMMIT;


-- ============================================================================
-- PART 2 — Read-only integrity check (run before and after each pgbench run)
-- Expected every time: account_count 20, total_balance 1801800.00
-- (total_matches_baseline = true), negative_balances 0, other_log_rows 0.
-- Expected after a run: that variant's log rows increase by the number of
-- successful pgbench transactions, and its log amount by the same x 1.00.
-- ============================================================================
SELECT
    CURRENT_TIMESTAMP                                  AS checked_at,
    COUNT(*)                                           AS account_count,
    SUM(a.balance)                                     AS total_balance,
    SUM(a.balance) = 1801800.00                        AS total_matches_baseline,
    MIN(a.balance)                                     AS min_balance,
    MAX(a.balance)                                     AS max_balance,
    COUNT(*) FILTER (WHERE a.balance < 0)              AS negative_balances,
    (SELECT COUNT(*) FROM p3_lab.transfer_log
     WHERE variant = 'UNORDERED')                      AS unordered_log_rows,
    (SELECT COALESCE(SUM(amount), 0.00) FROM p3_lab.transfer_log
     WHERE variant = 'UNORDERED')                      AS unordered_log_amount,
    (SELECT COUNT(*) FROM p3_lab.transfer_log
     WHERE variant = 'ORDERED')                        AS ordered_log_rows,
    (SELECT COALESCE(SUM(amount), 0.00) FROM p3_lab.transfer_log
     WHERE variant = 'ORDERED')                        AS ordered_log_amount,
    (SELECT COUNT(*) FROM p3_lab.transfer_log
     WHERE variant NOT IN ('UNORDERED', 'ORDERED'))    AS other_log_rows
FROM p3_lab.accounts AS a;
