-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_13_lab_setup.sql
-- Description:  ONE-TIME SETUP for the remaining Portfolio 3 experiments.
--
-- WHAT THIS SCRIPT DOES (one atomic transaction):
--   A. Ledger-backed lab wallets (used with public.korapay_transfer_funds):
--        * 20 fictional VERIFIED customers
--            p3lab.customer.001 ... 020 @example.invalid, P3L-TEL-000001 ... 020
--        * one ACTIVE NGN CUSTOMER wallet each (customer_id is UNIQUE in
--          wallets): P3LW000001 ... P3LW000020, opening balance 0.00
--        * each wallet funded with NGN 100,000.00 by a balanced DEPOSIT from
--          the SYSTEM_CLEARING wallet, P3L-DEP-001 ... P3L-DEP-020, each with
--          one DEBIT (clearing) and one CREDIT (lab wallet).
--   B. Schema p3_lab, separate from the financial tables:
--        * p3_lab.accounts and p3_lab.transfer_log — for the DELIBERATELY
--          INCONSISTENT demonstrations (lost update, deadlock, isolation
--          anomalies, ordered/unordered workload). They have no foreign keys
--          to, and are not referenced by, customers, wallets, transactions or
--          ledger_entries, so those demonstrations cannot damage the ledger.
--        * p3_lab.setup_baseline — a one-row evidence snapshot of the
--          database taken before any lab change, used by later verification.
--   C. Assertions before COMMIT; any failure raises an exception and nothing
--      is committed.
--
-- WHAT THIS SCRIPT DOES NOT CHANGE:
--   No existing customer, transaction or ledger entry is modified, and no
--   balance is reset. The ONLY existing row that changes is the
--   SYSTEM_CLEARING wallet: its balance falls by exactly 2,000,000.00
--   (20 x 100,000.00) and it gains 20 DEBIT ledger entries. That expected
--   change is excluded from every "existing wallets unchanged" check below.
--   Portfolio 2 records and the existing P3 wallets (P3W...), transactions
--   and screenshots are not touched.
--
-- RUN ONCE ONLY:
--   The guard stops before any change if schema p3_lab, any P3L customer,
--   wallet or transaction already exists, or if the database does not
--   reconcile beforehand.
--
-- HOW TO RUN (Command Prompt, cmd.exe; output saved automatically):
--   cd /d C:\Users\HP\Desktop\Aibangbee_Sandra_2026_A_MIT_0301_301897710\portfolio-3-transactions-concurrency
--   if not exist output mkdir output
--   "C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -h localhost -U postgres -d korapay_wallet -v ON_ERROR_STOP=1 -a -f sql\Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_13_lab_setup.sql > output\Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_13_lab_setup.log 2>&1
--
--   -a echoes every statement into the log; "2>&1" also captures NOTICE and
--   ERROR messages. The psql password prompt still appears in the console.
--   If psql stops with an error, nothing from this script has been saved.
-- ============================================================================

\set ON_ERROR_STOP on
\pset null '(null)'

\echo '=== P3 lab setup: 20 ledger-backed lab wallets and schema p3_lab ==='

BEGIN;

-- ----------------------------------------------------------------------------
-- STAGE 1: Guard checks (read-only)
--   1a. Nothing from this setup may already exist.
--   1b. Exactly one SYSTEM_CLEARING wallet, and it is ACTIVE.
--   1c. Every wallet already reconciles with its ledger, so any later
--       mismatch can only come from the lab work.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    -- 1a. Run-once guard.
    IF to_regnamespace('p3_lab') IS NOT NULL THEN
        RAISE EXCEPTION 'GUARD: schema p3_lab already exists. This setup runs once only.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM customers
    WHERE email LIKE 'p3lab.customer.%@example.invalid'
       OR phone_number LIKE 'P3L-TEL-%';
    IF v_count > 0 THEN
        RAISE EXCEPTION 'GUARD: % P3 lab customer(s) already exist.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM wallets WHERE wallet_number LIKE 'P3LW%';
    IF v_count > 0 THEN
        RAISE EXCEPTION 'GUARD: % P3 lab wallet(s) already exist.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM transactions WHERE reference LIKE 'P3L-%';
    IF v_count > 0 THEN
        RAISE EXCEPTION 'GUARD: % P3L transaction(s) already exist.', v_count;
    END IF;

    -- 1b. Clearing wallet.
    SELECT COUNT(*) INTO v_count FROM wallets WHERE wallet_type = 'SYSTEM_CLEARING';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'GUARD: expected exactly 1 SYSTEM_CLEARING wallet, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM wallets
    WHERE wallet_type = 'SYSTEM_CLEARING' AND status = 'ACTIVE';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'GUARD: the SYSTEM_CLEARING wallet is not ACTIVE.';
    END IF;

    -- 1c. Whole-database reconciliation (CREDIT adds, DEBIT subtracts).
    SELECT COUNT(*) INTO v_count
    FROM wallets AS w
    LEFT JOIN (
        SELECT wallet_id,
               SUM(CASE entry_type WHEN 'CREDIT' THEN amount
                                   WHEN 'DEBIT'  THEN -amount END) AS ledger_total
        FROM ledger_entries
        GROUP BY wallet_id
    ) AS lm ON lm.wallet_id = w.wallet_id
    WHERE w.balance <> COALESCE(lm.ledger_total, 0.00);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'GUARD: % wallet(s) do not reconcile before setup.', v_count;
    END IF;

    RAISE NOTICE 'Stage 1 passed: no lab objects exist, clearing wallet ACTIVE, all wallets reconcile.';
END $$;


-- ----------------------------------------------------------------------------
-- STAGE 2: Schema p3_lab and its tables
-- ----------------------------------------------------------------------------
CREATE SCHEMA p3_lab;

COMMENT ON SCHEMA p3_lab IS
    'Portfolio 3 lab schema. accounts and transfer_log are for deliberately inconsistent concurrency demonstrations and are independent of the KoraPay financial tables. setup_baseline holds evidence captured before lab setup.';

-- Lab accounts for deliberately unsafe demonstrations. There is deliberately
-- NO balance >= 0 CHECK, so lost updates and overspending remain visible
-- instead of being blocked. These rows may be reset by later lab scripts;
-- that is acceptable because nothing in the ledger depends on them.
CREATE TABLE p3_lab.accounts (
    account_id   INTEGER        NOT NULL,
    account_name VARCHAR(50)    NOT NULL,
    balance      NUMERIC(18,2)  NOT NULL,
    updated_at   TIMESTAMPTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_p3_lab_accounts PRIMARY KEY (account_id)
);

-- Record of lab-table transfers, used to check the ordered and unordered
-- workloads (for example, total moved versus balance totals).
CREATE TABLE p3_lab.transfer_log (
    log_id          BIGSERIAL      NOT NULL,
    variant         VARCHAR(20)    NOT NULL,
    from_account_id INTEGER        NOT NULL,
    to_account_id   INTEGER        NOT NULL,
    amount          NUMERIC(18,2)  NOT NULL,
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_p3_lab_transfer_log PRIMARY KEY (log_id),
    CONSTRAINT fk_p3_lab_transfer_log_from FOREIGN KEY (from_account_id)
        REFERENCES p3_lab.accounts (account_id),
    CONSTRAINT fk_p3_lab_transfer_log_to FOREIGN KEY (to_account_id)
        REFERENCES p3_lab.accounts (account_id)
);

-- One-row evidence snapshot of the database BEFORE any lab change.
CREATE TABLE p3_lab.setup_baseline (
    captured_at                  TIMESTAMPTZ    NOT NULL,
    customer_count               BIGINT         NOT NULL,
    wallet_count                 BIGINT         NOT NULL,
    transaction_count            BIGINT         NOT NULL,
    ledger_entry_count           BIGINT         NOT NULL,
    max_transaction_id           BIGINT         NOT NULL,
    max_ledger_entry_id          BIGINT         NOT NULL,
    total_wallet_balance         NUMERIC(18,2)  NOT NULL,
    clearing_wallet_id           BIGINT         NOT NULL,
    clearing_balance             NUMERIC(18,2)  NOT NULL,
    existing_customer_wallet_count   BIGINT         NOT NULL,
    existing_customer_wallet_balance NUMERIC(18,2)  NOT NULL,
    existing_customer_wallet_last_update TIMESTAMPTZ,
    p3w_wallet_balance           NUMERIC(18,2)  NOT NULL,
    customer_last_update         TIMESTAMPTZ,
    successful_transaction_count BIGINT         NOT NULL,
    pending_transaction_count    BIGINT         NOT NULL,
    failed_transaction_count     BIGINT         NOT NULL,
    reversed_transaction_count   BIGINT         NOT NULL
);


-- ----------------------------------------------------------------------------
-- STAGE 3: Baseline evidence (before any lab customer, wallet or deposit)
-- "Existing customer wallets" = every CUSTOMER wallet that exists now
-- (Portfolio 1, Portfolio 2 and P3W...). The SYSTEM_CLEARING wallet is
-- recorded separately because funding is expected to change it.
-- ----------------------------------------------------------------------------
INSERT INTO p3_lab.setup_baseline
SELECT
    CURRENT_TIMESTAMP,
    (SELECT COUNT(*) FROM customers),
    (SELECT COUNT(*) FROM wallets),
    (SELECT COUNT(*) FROM transactions),
    (SELECT COUNT(*) FROM ledger_entries),
    (SELECT COALESCE(MAX(transaction_id), 0) FROM transactions),
    (SELECT COALESCE(MAX(ledger_entry_id), 0) FROM ledger_entries),
    (SELECT COALESCE(SUM(balance), 0.00) FROM wallets),
    (SELECT wallet_id FROM wallets WHERE wallet_type = 'SYSTEM_CLEARING'),
    (SELECT balance   FROM wallets WHERE wallet_type = 'SYSTEM_CLEARING'),
    (SELECT COUNT(*) FROM wallets WHERE wallet_type = 'CUSTOMER'),
    (SELECT COALESCE(SUM(balance), 0.00) FROM wallets WHERE wallet_type = 'CUSTOMER'),
    (SELECT MAX(updated_at) FROM wallets WHERE wallet_type = 'CUSTOMER'),
    (SELECT COALESCE(SUM(balance), 0.00) FROM wallets WHERE wallet_number LIKE 'P3W%'),
    (SELECT MAX(updated_at) FROM customers),
    (SELECT COUNT(*) FROM transactions WHERE status = 'SUCCESSFUL'),
    (SELECT COUNT(*) FROM transactions WHERE status = 'PENDING'),
    (SELECT COUNT(*) FROM transactions WHERE status = 'FAILED'),
    (SELECT COUNT(*) FROM transactions WHERE status = 'REVERSED');


-- ----------------------------------------------------------------------------
-- STAGE 4: Seed the lab accounts (independent of the ledger)
-- 20 accounts of 100,000.00 each, total 2,000,000.00.
-- ----------------------------------------------------------------------------
INSERT INTO p3_lab.accounts (account_id, account_name, balance)
SELECT
    n,
    'Lab account ' || LPAD(n::TEXT, 2, '0'),
    100000.00
FROM generate_series(1, 20) AS g (n);


-- ----------------------------------------------------------------------------
-- STAGE 5: 20 fictional lab customers and one wallet each
-- customer_id is looked up through the unique email, never hard-coded.
-- ----------------------------------------------------------------------------
INSERT INTO customers
    (first_name, last_name, email, phone_number, verification_status)
SELECT
    'Lab',
    'Customer ' || LPAD(n::TEXT, 3, '0'),
    'p3lab.customer.' || LPAD(n::TEXT, 3, '0') || '@example.invalid',
    'P3L-TEL-' || LPAD(n::TEXT, 6, '0'),
    'VERIFIED'
FROM generate_series(1, 20) AS g (n);

INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, currency, balance, status)
SELECT
    c.customer_id,
    'P3LW' || LPAD(g.n::TEXT, 6, '0'),
    'CUSTOMER',
    'NGN',
    0.00,
    'ACTIVE'
FROM generate_series(1, 20) AS g (n)
JOIN customers AS c
    ON c.email = 'p3lab.customer.' || LPAD(g.n::TEXT, 3, '0') || '@example.invalid';


-- ----------------------------------------------------------------------------
-- STAGE 6: Fund each lab wallet with 100,000.00 from SYSTEM_CLEARING
--   6a. Lock the clearing wallet and all 20 lab wallets in ascending
--       wallet_id order (FOR NO KEY UPDATE, the same lock level as
--       public.korapay_transfer_funds; only balance and updated_at change).
--   6b. Validate the locked rows.
--   6c. For each lab wallet, in wallet_number order:
--         - insert DEPOSIT P3L-DEP-NNN as PENDING;
--         - debit the clearing wallet and credit the lab wallet, taking each
--           resulting balance from UPDATE ... RETURNING;
--         - insert one DEBIT (clearing) and one CREDIT (lab wallet) with
--           those balances as balance_after;
--         - mark the deposit SUCCESSFUL.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    c_amount         CONSTANT NUMERIC(18,2) := 100000.00;
    v_clearing_id    BIGINT;
    v_clearing_after NUMERIC(18,2);
    v_wallet_after   NUMERIC(18,2);
    v_transaction_id BIGINT;
    v_locked         BIGINT := 0;
    v_count          BIGINT;
    r                RECORD;
BEGIN
    SELECT wallet_id INTO STRICT v_clearing_id
    FROM wallets
    WHERE wallet_type = 'SYSTEM_CLEARING';

    -- 6a. Ordered locks.
    FOR r IN
        SELECT wallet_id
        FROM wallets
        WHERE wallet_id = v_clearing_id
           OR wallet_number LIKE 'P3LW%'
        ORDER BY wallet_id
        FOR NO KEY UPDATE
    LOOP
        v_locked := v_locked + 1;
    END LOOP;

    IF v_locked <> 21 THEN
        RAISE EXCEPTION 'Stage 6: expected to lock 21 wallets (clearing + 20 lab), locked %.', v_locked;
    END IF;

    -- 6b. Validation while the locks are held.
    SELECT COUNT(*) INTO v_count
    FROM wallets
    WHERE wallet_id = v_clearing_id AND status = 'ACTIVE' AND currency = 'NGN';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Stage 6: SYSTEM_CLEARING wallet is not ACTIVE NGN.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM wallets
    WHERE wallet_number LIKE 'P3LW%'
      AND wallet_type = 'CUSTOMER'
      AND status = 'ACTIVE'
      AND currency = 'NGN'
      AND balance = 0.00;
    IF v_count <> 20 THEN
        RAISE EXCEPTION 'Stage 6: expected 20 ACTIVE NGN lab wallets at 0.00, found %.', v_count;
    END IF;

    -- 6c. One balanced DEPOSIT per lab wallet.
    FOR r IN
        SELECT wallet_id, wallet_number
        FROM wallets
        WHERE wallet_number LIKE 'P3LW%'
        ORDER BY wallet_number
    LOOP
        INSERT INTO transactions
            (reference, transaction_type, source_wallet_id, destination_wallet_id,
             amount, status, description)
        VALUES
            ('P3L-DEP-' || RIGHT(r.wallet_number, 3), 'DEPOSIT', v_clearing_id, r.wallet_id,
             c_amount, 'PENDING', 'P3 lab setup: funding deposit')
        RETURNING transaction_id INTO v_transaction_id;

        UPDATE wallets
        SET balance    = balance - c_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE wallet_id = v_clearing_id
        RETURNING balance INTO v_clearing_after;

        UPDATE wallets
        SET balance    = balance + c_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE wallet_id = r.wallet_id
        RETURNING balance INTO v_wallet_after;

        INSERT INTO ledger_entries
            (transaction_id, wallet_id, entry_type, amount, balance_after)
        VALUES
            (v_transaction_id, v_clearing_id, 'DEBIT',  c_amount, v_clearing_after),
            (v_transaction_id, r.wallet_id,   'CREDIT', c_amount, v_wallet_after);

        UPDATE transactions
        SET status = 'SUCCESSFUL'
        WHERE transaction_id = v_transaction_id;
    END LOOP;

    RAISE NOTICE 'Stage 6 posted 20 funding deposits. Clearing balance now %.', v_clearing_after;
END $$;


-- ----------------------------------------------------------------------------
-- STAGE 7: Assertions before COMMIT
-- Any failure raises an exception; the transaction is then aborted and the
-- COMMIT below performs a rollback, so nothing is saved.
--   V1. Row count deltas: +20 customers, +20 wallets, +20 transactions,
--       +40 ledger entries.
--   V2. 20 lab wallets: ACTIVE NGN CUSTOMER, each 100,000.00, each owned by
--       a different VERIFIED lab customer.
--   V3. 20 SUCCESSFUL DEPOSITs of 100,000.00, clearing -> lab wallet.
--   V4. Each deposit has exactly one DEBIT on the clearing wallet and one
--       CREDIT on its lab wallet, with correct balance_after values.
--   V5. Clearing balance fell by exactly 2,000,000.00.
--   V6. Clearing and lab wallets reconcile with the ledger.
--   V7. Existing customer wallets, customers and transactions unchanged
--       (the clearing wallet is excluded: its change is expected).
--   V8. Total of all wallet balances unchanged (money conserved).
--   V9. Lab accounts: 20 rows totalling 2,000,000.00; transfer_log empty.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    c_amount  CONSTANT NUMERIC(18,2) := 100000.00;
    b         p3_lab.setup_baseline%ROWTYPE;
    v_count   BIGINT;
    v_amount  NUMERIC(18,2);
    v_last    TIMESTAMPTZ;
BEGIN
    SELECT * INTO STRICT b FROM p3_lab.setup_baseline;

    -- V1.
    SELECT COUNT(*) INTO v_count FROM customers;
    IF v_count <> b.customer_count + 20 THEN
        RAISE EXCEPTION 'V1 failed: customers expected %, found %.', b.customer_count + 20, v_count;
    END IF;
    SELECT COUNT(*) INTO v_count FROM wallets;
    IF v_count <> b.wallet_count + 20 THEN
        RAISE EXCEPTION 'V1 failed: wallets expected %, found %.', b.wallet_count + 20, v_count;
    END IF;
    SELECT COUNT(*) INTO v_count FROM transactions;
    IF v_count <> b.transaction_count + 20 THEN
        RAISE EXCEPTION 'V1 failed: transactions expected %, found %.', b.transaction_count + 20, v_count;
    END IF;
    SELECT COUNT(*) INTO v_count FROM ledger_entries;
    IF v_count <> b.ledger_entry_count + 40 THEN
        RAISE EXCEPTION 'V1 failed: ledger entries expected %, found %.', b.ledger_entry_count + 40, v_count;
    END IF;

    -- V2.
    SELECT COUNT(DISTINCT w.customer_id) INTO v_count
    FROM wallets AS w
    JOIN customers AS c ON c.customer_id = w.customer_id
    WHERE w.wallet_number LIKE 'P3LW%'
      AND w.wallet_type = 'CUSTOMER'
      AND w.currency = 'NGN'
      AND w.status = 'ACTIVE'
      AND w.balance = c_amount
      AND c.verification_status = 'VERIFIED'
      AND c.email LIKE 'p3lab.customer.%@example.invalid';
    IF v_count <> 20 THEN
        RAISE EXCEPTION 'V2 failed: expected 20 valid lab wallets with distinct owners, found %.', v_count;
    END IF;

    -- V3.
    SELECT COUNT(*) INTO v_count
    FROM transactions AS t
    JOIN wallets AS dw ON dw.wallet_id = t.destination_wallet_id
    WHERE t.reference LIKE 'P3L-DEP-%'
      AND t.transaction_type = 'DEPOSIT'
      AND t.status = 'SUCCESSFUL'
      AND t.amount = c_amount
      AND t.source_wallet_id = b.clearing_wallet_id
      AND t.reversal_of_transaction_id IS NULL
      AND dw.wallet_number = 'P3LW000' || RIGHT(t.reference, 3);
    IF v_count <> 20 THEN
        RAISE EXCEPTION 'V3 failed: expected 20 SUCCESSFUL funding deposits, found %.', v_count;
    END IF;

    -- V4. Ledger pairs. The clearing DEBIT of deposit NNN must show the
    --     clearing balance after NNN deposits; each CREDIT shows 100,000.00.
    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN transactions AS t ON t.transaction_id = le.transaction_id
    WHERE t.reference LIKE 'P3L-DEP-%';
    IF v_count <> 40 THEN
        RAISE EXCEPTION 'V4 failed: expected 40 funding ledger entries, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN transactions AS t ON t.transaction_id = le.transaction_id
    WHERE t.reference LIKE 'P3L-DEP-%'
      AND le.entry_type = 'DEBIT'
      AND le.wallet_id = b.clearing_wallet_id
      AND le.amount = c_amount
      AND le.balance_after = b.clearing_balance - c_amount * RIGHT(t.reference, 3)::INTEGER;
    IF v_count <> 20 THEN
        RAISE EXCEPTION 'V4 failed: expected 20 correct clearing DEBIT entries, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries AS le
    JOIN transactions AS t ON t.transaction_id = le.transaction_id
    WHERE t.reference LIKE 'P3L-DEP-%'
      AND le.entry_type = 'CREDIT'
      AND le.wallet_id = t.destination_wallet_id
      AND le.amount = c_amount
      AND le.balance_after = c_amount;
    IF v_count <> 20 THEN
        RAISE EXCEPTION 'V4 failed: expected 20 correct lab CREDIT entries, found %.', v_count;
    END IF;

    -- V5.
    SELECT balance INTO STRICT v_amount FROM wallets WHERE wallet_id = b.clearing_wallet_id;
    IF v_amount <> b.clearing_balance - c_amount * 20 THEN
        RAISE EXCEPTION 'V5 failed: clearing balance expected %, found %.',
            b.clearing_balance - c_amount * 20, v_amount;
    END IF;

    -- V6.
    SELECT COUNT(*) INTO v_count
    FROM wallets AS w
    LEFT JOIN (
        SELECT le.wallet_id,
               SUM(CASE le.entry_type WHEN 'CREDIT' THEN le.amount
                                      WHEN 'DEBIT'  THEN -le.amount END) AS ledger_total
        FROM ledger_entries AS le
        JOIN wallets AS lw ON lw.wallet_id = le.wallet_id
        WHERE lw.wallet_type = 'SYSTEM_CLEARING' OR lw.wallet_number LIKE 'P3LW%'
        GROUP BY le.wallet_id
    ) AS lm ON lm.wallet_id = w.wallet_id
    WHERE (w.wallet_type = 'SYSTEM_CLEARING' OR w.wallet_number LIKE 'P3LW%')
      AND w.balance <> COALESCE(lm.ledger_total, 0.00);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'V6 failed: % clearing/lab wallet(s) do not reconcile.', v_count;
    END IF;

    -- V7. Existing data unchanged (SYSTEM_CLEARING excluded on purpose).
    SELECT COUNT(*), COALESCE(SUM(balance), 0.00), MAX(updated_at)
    INTO v_count, v_amount, v_last
    FROM wallets
    WHERE wallet_type = 'CUSTOMER'
      AND wallet_number NOT LIKE 'P3LW%';
    IF v_count <> b.existing_customer_wallet_count
       OR v_amount <> b.existing_customer_wallet_balance
       OR v_last IS DISTINCT FROM b.existing_customer_wallet_last_update THEN
        RAISE EXCEPTION 'V7 failed: an existing customer wallet changed.';
    END IF;

    SELECT COALESCE(SUM(balance), 0.00) INTO v_amount FROM wallets WHERE wallet_number LIKE 'P3W%';
    IF v_amount <> b.p3w_wallet_balance THEN
        RAISE EXCEPTION 'V7 failed: existing P3W wallet balances changed.';
    END IF;

    SELECT MAX(updated_at) INTO v_last
    FROM customers
    WHERE email NOT LIKE 'p3lab.customer.%@example.invalid';
    IF v_last IS DISTINCT FROM b.customer_last_update THEN
        RAISE EXCEPTION 'V7 failed: an existing customer changed.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference NOT LIKE 'P3L-%' AND status = 'SUCCESSFUL';
    IF v_count <> b.successful_transaction_count THEN
        RAISE EXCEPTION 'V7 failed: existing SUCCESSFUL transactions changed.';
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference NOT LIKE 'P3L-%' AND status = 'PENDING';
    IF v_count <> b.pending_transaction_count THEN
        RAISE EXCEPTION 'V7 failed: existing PENDING transactions changed.';
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference NOT LIKE 'P3L-%' AND status = 'FAILED';
    IF v_count <> b.failed_transaction_count THEN
        RAISE EXCEPTION 'V7 failed: existing FAILED transactions changed.';
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference NOT LIKE 'P3L-%' AND status = 'REVERSED';
    IF v_count <> b.reversed_transaction_count THEN
        RAISE EXCEPTION 'V7 failed: existing REVERSED transactions changed.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE ledger_entry_id <= b.max_ledger_entry_id;
    IF v_count <> b.ledger_entry_count THEN
        RAISE EXCEPTION 'V7 failed: existing ledger entries changed in number.';
    END IF;

    -- V8. Money conserved across all wallets.
    SELECT COALESCE(SUM(balance), 0.00) INTO v_amount FROM wallets;
    IF v_amount <> b.total_wallet_balance THEN
        RAISE EXCEPTION 'V8 failed: total wallet balance changed from % to %.',
            b.total_wallet_balance, v_amount;
    END IF;

    -- V9.
    SELECT COUNT(*), COALESCE(SUM(balance), 0.00) INTO v_count, v_amount FROM p3_lab.accounts;
    IF v_count <> 20 OR v_amount <> 2000000.00 THEN
        RAISE EXCEPTION 'V9 failed: lab accounts % rows totalling %.', v_count, v_amount;
    END IF;
    SELECT COUNT(*) INTO v_count FROM p3_lab.transfer_log;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'V9 failed: transfer_log is not empty.';
    END IF;

    RAISE NOTICE 'Stage 7: all pre-commit assertions passed.';
END $$;

COMMIT;


-- ----------------------------------------------------------------------------
-- STAGE 8: Post-commit evidence (read-only)
-- ----------------------------------------------------------------------------
\echo '--- Baseline snapshot captured before setup ---'
SELECT * FROM p3_lab.setup_baseline;

\echo '--- SYSTEM_CLEARING wallet: baseline versus now (expected change -2,000,000.00) ---'
SELECT
    w.wallet_id,
    w.wallet_number,
    b.clearing_balance            AS baseline_balance,
    w.balance                     AS current_balance,
    w.balance - b.clearing_balance AS change
FROM wallets AS w
CROSS JOIN p3_lab.setup_baseline AS b
WHERE w.wallet_id = b.clearing_wallet_id;

\echo '--- Lab wallets with ledger reconciliation ---'
SELECT
    w.wallet_id,
    w.wallet_number,
    c.email,
    w.status,
    w.balance AS cached_balance,
    COALESCE(SUM(CASE le.entry_type WHEN 'CREDIT' THEN le.amount
                                    WHEN 'DEBIT'  THEN -le.amount END), 0.00) AS ledger_total,
    COUNT(le.ledger_entry_id) AS ledger_entry_count,
    w.balance = COALESCE(SUM(CASE le.entry_type WHEN 'CREDIT' THEN le.amount
                                                WHEN 'DEBIT'  THEN -le.amount END), 0.00) AS reconciled
FROM wallets AS w
JOIN customers AS c ON c.customer_id = w.customer_id
LEFT JOIN ledger_entries AS le ON le.wallet_id = w.wallet_id
WHERE w.wallet_number LIKE 'P3LW%'
GROUP BY w.wallet_id, w.wallet_number, c.email, w.status, w.balance
ORDER BY w.wallet_number;

\echo '--- Funding deposits ---'
SELECT
    t.transaction_id,
    t.reference,
    dw.wallet_number AS destination_wallet,
    t.amount,
    t.status
FROM transactions AS t
JOIN wallets AS dw ON dw.wallet_id = t.destination_wallet_id
WHERE t.reference LIKE 'P3L-DEP-%'
ORDER BY t.reference;

\echo '--- Lab accounts (independent of the ledger) ---'
SELECT
    COUNT(*)      AS account_count,
    SUM(balance)  AS total_balance,
    MIN(balance)  AS min_balance,
    MAX(balance)  AS max_balance
FROM p3_lab.accounts;

\echo '=== P3 lab setup committed ==='
