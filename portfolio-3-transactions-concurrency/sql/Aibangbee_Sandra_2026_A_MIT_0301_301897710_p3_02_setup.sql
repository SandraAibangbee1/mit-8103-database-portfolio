-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql
-- Description:  ONE-TIME DEMONSTRATION SETUP for the Portfolio 3 transaction
--               and concurrency demonstrations.
--
-- WHAT THIS SCRIPT DOES (one atomic transaction):
--   * Creates 3 fictional VERIFIED customers   p3.customer.001..003@example.invalid
--   * Creates their ACTIVE NGN wallets         P3W0000001, P3W0000002, P3W0000003
--     with opening balances of 0.00.
--   * Funds P3W0000001 with NGN 10,000.00 from the SYSTEM_CLEARING wallet as
--     DEPOSIT 'P3-DEP-001', with one DEBIT and one CREDIT ledger entry.
--   * Validates the result before COMMIT and raises an exception on any
--     mismatch, so either everything is committed or nothing is.
--
-- WHAT THIS SCRIPT DOES NOT CHANGE:
--   No existing customer or transaction is modified. The only existing wallet
--   changed is SYSTEM_CLEARING (its balance falls by 10,000.00 and it gains one
--   DEBIT ledger entry). Portfolio 2 benchmark records (P2W..., P2-...) are not
--   touched, and no table, index, function or trigger is created or altered.
--   Only a session-scoped TEMP table (ON COMMIT DROP) holds the baseline.
--
-- RUN ONCE ONLY:
--   Stage 1 stops with an exception if any P3 customer, wallet or transaction
--   identifier already exists. Duplicates are never silently skipped.
--
-- HOW TO RUN (pgAdmin Query Tool, connected to korapay_wallet):
--   1. Run Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_01_preflight.sql first and record its results.
--   2. Execute this whole script once (F5).
--   3. If any error is reported, nothing has been saved. Run ROLLBACK; before
--      running anything else in the same Query Tool tab.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- STAGE 1: Guard checks (run-once and clearing wallet pre-conditions)
--   1a. No proposed P3 identifier may already exist.
--   1b. Exactly one SYSTEM_CLEARING wallet must exist.
--   1c. Its cached balance must already match its ledger, so any later
--       reconciliation failure is attributable to this script.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_p3_customers     BIGINT;
    v_p3_wallets       BIGINT;
    v_p3_transactions  BIGINT;
    v_clearing_count   BIGINT;
    v_clearing_id      BIGINT;
    v_clearing_balance NUMERIC(18,2);
    v_clearing_ledger  NUMERIC(18,2);
BEGIN
    -- 1a. Run-once guard.
    SELECT COUNT(*) INTO v_p3_customers
    FROM customers
    WHERE email LIKE 'p3.customer.%@example.invalid'
       OR phone_number LIKE 'P3-TEL-%';

    SELECT COUNT(*) INTO v_p3_wallets
    FROM wallets
    WHERE wallet_number LIKE 'P3W%';

    SELECT COUNT(*) INTO v_p3_transactions
    FROM transactions
    WHERE reference LIKE 'P3-%';

    IF v_p3_customers + v_p3_wallets + v_p3_transactions > 0 THEN
        RAISE EXCEPTION 'Portfolio 3 records already exist (customers %, wallets %, transactions %). This setup runs once only.',
            v_p3_customers, v_p3_wallets, v_p3_transactions;
    END IF;

    -- 1b. Exactly one SYSTEM_CLEARING wallet.
    SELECT COUNT(*) INTO v_clearing_count
    FROM wallets
    WHERE wallet_type = 'SYSTEM_CLEARING';

    IF v_clearing_count <> 1 THEN
        RAISE EXCEPTION 'Expected exactly 1 SYSTEM_CLEARING wallet, found %.', v_clearing_count;
    END IF;

    SELECT wallet_id, balance INTO v_clearing_id, v_clearing_balance
    FROM wallets
    WHERE wallet_type = 'SYSTEM_CLEARING';

    -- 1c. Clearing wallet must already reconcile (CREDIT adds, DEBIT subtracts).
    SELECT COALESCE(SUM(CASE entry_type
                            WHEN 'CREDIT' THEN  amount
                            WHEN 'DEBIT'  THEN -amount
                        END), 0.00)
    INTO v_clearing_ledger
    FROM ledger_entries
    WHERE wallet_id = v_clearing_id;

    IF v_clearing_balance <> v_clearing_ledger THEN
        RAISE EXCEPTION 'Clearing wallet % is not reconciled before setup (cached %, ledger %).',
            v_clearing_id, v_clearing_balance, v_clearing_ledger;
    END IF;

    RAISE NOTICE 'Stage 1 passed. Clearing wallet id %, opening balance %.',
        v_clearing_id, v_clearing_balance;
END $$;

-- ----------------------------------------------------------------------------
-- STAGE 2: Baseline snapshot of existing data
-- Used in Stage 6 to prove that existing records were preserved and that the
-- only existing wallet changed is SYSTEM_CLEARING. The clearing balance is
-- read here, before the Stage 5 lock; if another session changed it in
-- between, Stage 6 fails safely and nothing is committed.
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE p3_baseline ON COMMIT DROP AS
SELECT
    (SELECT COUNT(*) FROM customers)                               AS customer_count,
    (SELECT COUNT(*) FROM wallets)                                 AS wallet_count,
    (SELECT COUNT(*) FROM transactions)                            AS transaction_count,
    (SELECT COUNT(*) FROM ledger_entries)                          AS ledger_entry_count,
    (SELECT wallet_id FROM wallets
     WHERE wallet_type = 'SYSTEM_CLEARING')                        AS clearing_wallet_id,
    (SELECT balance FROM wallets
     WHERE wallet_type = 'SYSTEM_CLEARING')                        AS clearing_balance,
    (SELECT COALESCE(SUM(balance), 0.00) FROM wallets
     WHERE wallet_type = 'CUSTOMER')                               AS customer_wallet_balance_total,
    (SELECT MAX(updated_at) FROM wallets
     WHERE wallet_type = 'CUSTOMER')                               AS customer_wallet_last_update,
    (SELECT MAX(updated_at) FROM customers)                        AS customer_last_update,
    (SELECT COUNT(*) FROM transactions
     WHERE status = 'SUCCESSFUL')                                  AS successful_transaction_count,
    (SELECT COUNT(*) FROM transactions
     WHERE status = 'PENDING')                                     AS pending_transaction_count;

-- ----------------------------------------------------------------------------
-- STAGE 3: Create the three fictional P3 customers
-- All names, emails and phone numbers are fictional. The .invalid domain is
-- reserved and can never receive mail.
-- ----------------------------------------------------------------------------
INSERT INTO customers
    (first_name, last_name, email, phone_number, verification_status)
VALUES
    ('Amaka',  'Okafor', 'p3.customer.001@example.invalid', 'P3-TEL-000001', 'VERIFIED'),
    ('Tunde',  'Bakare', 'p3.customer.002@example.invalid', 'P3-TEL-000002', 'VERIFIED'),
    ('Zainab', 'Bello',  'p3.customer.003@example.invalid', 'P3-TEL-000003', 'VERIFIED');

-- ----------------------------------------------------------------------------
-- STAGE 4: Create their ACTIVE NGN wallets with zero balances
-- customer_id is looked up through the unique email, never hard-coded.
-- ----------------------------------------------------------------------------
INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, currency, balance, status)
SELECT
    c.customer_id,
    v.wallet_number,
    'CUSTOMER',
    'NGN',
    0.00,
    'ACTIVE'
FROM (VALUES
        ('p3.customer.001@example.invalid', 'P3W0000001'),
        ('p3.customer.002@example.invalid', 'P3W0000002'),
        ('p3.customer.003@example.invalid', 'P3W0000003')
     ) AS v (email, wallet_number)
JOIN customers AS c
    ON c.email = v.email;

-- ----------------------------------------------------------------------------
-- STAGE 5: Fund P3W0000001 with NGN 10,000.00 from SYSTEM_CLEARING
-- Follows the posting flow in database-design.md Section 7:
--   5a. Claim the reference with a PENDING DEPOSIT.
--   5b. Lock both wallets in ascending wallet_id order (SELECT ... FOR UPDATE).
--   5c. Validate both wallets while the locks are held.
--   5d. Update both cached balances and updated_at.
--   5e. Write one DEBIT (clearing, money out) and one CREDIT (P3W0000001,
--       money in) with balance_after taken from the updated balances.
--   5f. Mark the transaction SUCCESSFUL.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    c_amount         CONSTANT NUMERIC(18,2) := 10000.00;
    c_reference      CONSTANT VARCHAR(64)   := 'P3-DEP-001';
    v_clearing_id    BIGINT;
    v_clearing_state VARCHAR(20);
    v_clearing_after NUMERIC(18,2);
    v_dest_id        BIGINT;
    v_dest_state     VARCHAR(20);
    v_dest_balance   NUMERIC(18,2);
    v_dest_after     NUMERIC(18,2);
    v_transaction_id BIGINT;
BEGIN
    -- Look up both wallet IDs dynamically.
    SELECT wallet_id INTO STRICT v_clearing_id
    FROM wallets
    WHERE wallet_type = 'SYSTEM_CLEARING';

    SELECT wallet_id INTO v_dest_id
    FROM wallets
    WHERE wallet_number = 'P3W0000001';

    IF v_dest_id IS NULL THEN
        RAISE EXCEPTION 'Destination wallet P3W0000001 was not found.';
    END IF;

    -- 5a. Claim the reference.
    INSERT INTO transactions
        (reference, transaction_type, source_wallet_id, destination_wallet_id,
         amount, status, description)
    VALUES
        (c_reference, 'DEPOSIT', v_clearing_id, v_dest_id,
         c_amount, 'PENDING', 'P3 demonstration setup: opening funding deposit')
    RETURNING transaction_id INTO v_transaction_id;

    -- 5b. Lock both wallets in ascending wallet_id order.
    PERFORM 1
    FROM wallets
    WHERE wallet_id IN (v_clearing_id, v_dest_id)
    ORDER BY wallet_id ASC
    FOR UPDATE;

    -- 5c. Validate while the locks are held.
    SELECT status INTO v_clearing_state
    FROM wallets
    WHERE wallet_id = v_clearing_id;

    IF v_clearing_state <> 'ACTIVE' THEN
        RAISE EXCEPTION 'SYSTEM_CLEARING wallet % is %, expected ACTIVE.',
            v_clearing_id, v_clearing_state;
    END IF;

    SELECT status, balance INTO v_dest_state, v_dest_balance
    FROM wallets
    WHERE wallet_id = v_dest_id;

    IF v_dest_state <> 'ACTIVE' OR v_dest_balance <> 0.00 THEN
        RAISE EXCEPTION 'Wallet P3W0000001 must be ACTIVE with 0.00 (found %, %).',
            v_dest_state, v_dest_balance;
    END IF;

    -- 5d. Update cached balances. The clearing wallet may go negative.
    UPDATE wallets
    SET balance    = balance - c_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_clearing_id
    RETURNING balance INTO v_clearing_after;

    UPDATE wallets
    SET balance    = balance + c_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_dest_id
    RETURNING balance INTO v_dest_after;

    -- 5e. One balanced DEBIT and CREDIT pair.
    INSERT INTO ledger_entries
        (transaction_id, wallet_id, entry_type, amount, balance_after)
    VALUES
        (v_transaction_id, v_clearing_id, 'DEBIT',  c_amount, v_clearing_after),
        (v_transaction_id, v_dest_id,     'CREDIT', c_amount, v_dest_after);

    -- 5f. Complete the transaction.
    UPDATE transactions
    SET status = 'SUCCESSFUL'
    WHERE transaction_id = v_transaction_id;

    RAISE NOTICE 'Stage 5 posted % (transaction id %): clearing balance %, P3W0000001 balance %.',
        c_reference, v_transaction_id, v_clearing_after, v_dest_after;
END $$;

-- ----------------------------------------------------------------------------
-- STAGE 6: Validation before COMMIT
-- Any failure raises an exception, which aborts the transaction so that the
-- COMMIT below performs a rollback and nothing is saved.
--   V1. Row counts grew by exactly 3 / 3 / 1 / 2.
--   V2. Three P3 wallets are ACTIVE NGN CUSTOMER wallets of VERIFIED P3 customers.
--   V3. P3-DEP-001 is a SUCCESSFUL DEPOSIT of 10,000.00 from clearing to P3W0000001.
--   V4. It has exactly one matching DEBIT and one matching CREDIT.
--   V5. Final balances: 10,000.00 / 0.00 / 0.00, clearing reduced by 10,000.00.
--   V6. Clearing and P3 wallets reconcile with their ledger entries.
--   V7. Existing customers, customer wallets and transactions are unchanged.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    c_amount  CONSTANT NUMERIC(18,2) := 10000.00;
    b         RECORD;
    t         RECORD;
    v_dest_id BIGINT;
    v_count   BIGINT;
    v_amount  NUMERIC(18,2);
    v_last    TIMESTAMPTZ;
BEGIN
    SELECT * INTO STRICT b FROM p3_baseline;

    -- V1. Row count deltas.
    SELECT COUNT(*) INTO v_count FROM customers;
    IF v_count <> b.customer_count + 3 THEN
        RAISE EXCEPTION 'V1 failed: expected % customers, found %.', b.customer_count + 3, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM wallets;
    IF v_count <> b.wallet_count + 3 THEN
        RAISE EXCEPTION 'V1 failed: expected % wallets, found %.', b.wallet_count + 3, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM transactions;
    IF v_count <> b.transaction_count + 1 THEN
        RAISE EXCEPTION 'V1 failed: expected % transactions, found %.', b.transaction_count + 1, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM ledger_entries;
    IF v_count <> b.ledger_entry_count + 2 THEN
        RAISE EXCEPTION 'V1 failed: expected % ledger entries, found %.', b.ledger_entry_count + 2, v_count;
    END IF;

    -- V2. Wallet and customer attributes.
    SELECT COUNT(*) INTO v_count
    FROM wallets AS w
    JOIN customers AS c ON c.customer_id = w.customer_id
    WHERE w.wallet_number IN ('P3W0000001', 'P3W0000002', 'P3W0000003')
      AND w.wallet_type = 'CUSTOMER'
      AND w.currency = 'NGN'
      AND w.status = 'ACTIVE'
      AND c.verification_status = 'VERIFIED'
      AND c.email LIKE 'p3.customer.%@example.invalid';

    IF v_count <> 3 THEN
        RAISE EXCEPTION 'V2 failed: expected 3 valid P3 wallets, found %.', v_count;
    END IF;

    -- V3. Funding transaction.
    SELECT wallet_id INTO STRICT v_dest_id
    FROM wallets
    WHERE wallet_number = 'P3W0000001';

    SELECT * INTO STRICT t
    FROM transactions
    WHERE reference = 'P3-DEP-001';

    IF t.transaction_type <> 'DEPOSIT'
       OR t.status <> 'SUCCESSFUL'
       OR t.amount <> c_amount
       OR t.source_wallet_id <> b.clearing_wallet_id
       OR t.destination_wallet_id <> v_dest_id
       OR t.reversal_of_transaction_id IS NOT NULL THEN
        RAISE EXCEPTION 'V3 failed: P3-DEP-001 is % / % / % from % to %.',
            t.transaction_type, t.status, t.amount, t.source_wallet_id, t.destination_wallet_id;
    END IF;

    -- V4. Exactly one matching DEBIT and one matching CREDIT.
    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE transaction_id = t.transaction_id;

    IF v_count <> 2 THEN
        RAISE EXCEPTION 'V4 failed: expected 2 ledger entries for P3-DEP-001, found %.', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE transaction_id = t.transaction_id
      AND entry_type     = 'DEBIT'
      AND wallet_id      = b.clearing_wallet_id
      AND amount         = c_amount
      AND balance_after  = b.clearing_balance - c_amount;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'V4 failed: clearing DEBIT entry is missing or incorrect.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM ledger_entries
    WHERE transaction_id = t.transaction_id
      AND entry_type     = 'CREDIT'
      AND wallet_id      = v_dest_id
      AND amount         = c_amount
      AND balance_after  = c_amount;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'V4 failed: P3W0000001 CREDIT entry is missing or incorrect.';
    END IF;

    -- V5. Final cached balances.
    SELECT COUNT(*) INTO v_count
    FROM wallets
    WHERE (wallet_number = 'P3W0000001' AND balance = c_amount)
       OR (wallet_number IN ('P3W0000002', 'P3W0000003') AND balance = 0.00);

    IF v_count <> 3 THEN
        RAISE EXCEPTION 'V5 failed: P3 wallet balances are not 10,000.00 / 0.00 / 0.00.';
    END IF;

    SELECT balance INTO STRICT v_amount
    FROM wallets
    WHERE wallet_id = b.clearing_wallet_id;

    IF v_amount <> b.clearing_balance - c_amount THEN
        RAISE EXCEPTION 'V5 failed: clearing balance expected %, found %.',
            b.clearing_balance - c_amount, v_amount;
    END IF;

    -- V6. Reconciliation for the clearing wallet and the three P3 wallets
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
        JOIN wallets AS lw ON lw.wallet_id = le.wallet_id
        WHERE lw.wallet_type = 'SYSTEM_CLEARING'
           OR lw.wallet_number LIKE 'P3W%'
        GROUP BY le.wallet_id
    ) AS lm
        ON lm.wallet_id = w.wallet_id
    WHERE (w.wallet_type = 'SYSTEM_CLEARING' OR w.wallet_number LIKE 'P3W%')
      AND w.balance <> COALESCE(lm.ledger_total, 0.00);

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'V6 failed: % wallet(s) do not reconcile with the ledger.', v_count;
    END IF;

    -- V7. Existing records preserved.
    SELECT COALESCE(SUM(balance), 0.00), MAX(updated_at) INTO v_amount, v_last
    FROM wallets
    WHERE wallet_type = 'CUSTOMER'
      AND wallet_number NOT LIKE 'P3W%';

    IF v_amount <> b.customer_wallet_balance_total
       OR v_last IS DISTINCT FROM b.customer_wallet_last_update THEN
        RAISE EXCEPTION 'V7 failed: an existing customer wallet was changed.';
    END IF;

    SELECT MAX(updated_at) INTO v_last
    FROM customers
    WHERE email NOT LIKE 'p3.customer.%@example.invalid';

    IF v_last IS DISTINCT FROM b.customer_last_update THEN
        RAISE EXCEPTION 'V7 failed: an existing customer was changed.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference NOT LIKE 'P3-%'
      AND status = 'SUCCESSFUL';

    IF v_count <> b.successful_transaction_count THEN
        RAISE EXCEPTION 'V7 failed: existing SUCCESSFUL transactions changed (% -> %).',
            b.successful_transaction_count, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM transactions
    WHERE reference NOT LIKE 'P3-%'
      AND status = 'PENDING';

    IF v_count <> b.pending_transaction_count THEN
        RAISE EXCEPTION 'V7 failed: existing PENDING transactions changed (% -> %).',
            b.pending_transaction_count, v_count;
    END IF;

    RAISE NOTICE 'Stage 6 passed: all validation checks succeeded.';
END $$;

COMMIT;

-- ----------------------------------------------------------------------------
-- STAGE 7: Post-commit evidence (read-only)
-- The three P3 wallets with cached balances and ledger reconciliation totals.
-- Expected: P3W0000001 10,000.00 (1 CREDIT), P3W0000002 and P3W0000003 0.00
-- (no entries), all reconciled = true.
-- ----------------------------------------------------------------------------
SELECT
    w.wallet_number,
    c.first_name || ' ' || c.last_name                           AS customer_name,
    w.status,
    w.balance                                                    AS cached_balance,
    COALESCE(SUM(le.amount) FILTER (WHERE le.entry_type = 'CREDIT'), 0.00) AS ledger_credits,
    COALESCE(SUM(le.amount) FILTER (WHERE le.entry_type = 'DEBIT'),  0.00) AS ledger_debits,
    COALESCE(SUM(CASE le.entry_type
                     WHEN 'CREDIT' THEN  le.amount
                     WHEN 'DEBIT'  THEN -le.amount
                 END), 0.00)                                     AS ledger_total,
    COUNT(le.ledger_entry_id)                                    AS ledger_entry_count,
    w.balance = COALESCE(SUM(CASE le.entry_type
                                 WHEN 'CREDIT' THEN  le.amount
                                 WHEN 'DEBIT'  THEN -le.amount
                             END), 0.00)                         AS reconciled
FROM wallets AS w
JOIN customers AS c
    ON c.customer_id = w.customer_id
LEFT JOIN ledger_entries AS le
    ON le.wallet_id = w.wallet_id
WHERE w.wallet_number LIKE 'P3W%'
GROUP BY
    w.wallet_id,
    w.wallet_number,
    c.first_name,
    c.last_name,
    w.status,
    w.balance
ORDER BY w.wallet_number;
