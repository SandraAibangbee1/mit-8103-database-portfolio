-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 2 — Query Optimisation
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_GenerateData.sql
-- Description:  SYNTHETIC BENCHMARK DATA GENERATION for KoraPay Wallet.
--
-- WHAT THIS SCRIPT IS:
--   A one-off, set-based loader that fills the existing Portfolio 1 schema
--   with a large, reproducible and internally consistent dataset so that
--   query plans and indexing strategies can be measured in Portfolio 2.
--
-- WHAT THIS SCRIPT IS NOT:
--   It is NOT an implementation of the production posting procedure and it
--   is NOT a concurrency-control mechanism. Transactions are written directly
--   as SUCCESSFUL and their ledger entries and balances are calculated in
--   bulk. The table lock in Stage 0 only keeps this single load self-contained.
--
-- DATASET PRODUCED (added to existing rows, nothing is removed):
--   *   5,000 fictional customers        email   p2.customer.NNNNN@example.invalid
--   *   5,000 customer wallets           number  P2W0000001 ... P2W0005000
--   *   5,000 funding DEPOSITs           ref     P2-DEP-00001 ... (from SYSTEM_CLEARING)
--   * 100,000 SUCCESSFUL TRANSFERs       ref     P2-TRF-000001 ...
--   * 210,000 ledger entries             exactly one DEBIT + one CREDIT per transaction
--
-- EXISTING DATA:
--   Portfolio 1 customers, wallets and the PENDING transaction
--   'test-reference-001' are preserved. No table is dropped, truncated,
--   recreated or altered, and no indexes are added to the KoraPay schema.
--   Only session-scoped TEMP tables (ON COMMIT DROP) are used as staging.
--
-- HOW TO RUN (pgAdmin Query Tool):
--   Execute the whole script once (F5). It is standard SQL and PL/pgSQL
--   with no psql meta-commands. If any error is reported, nothing has been
--   committed; run ROLLBACK; before issuing further statements.
-- ============================================================================

BEGIN;

-- ============================================================================
-- STAGE 0: Lock the four tables against concurrent writers for this load.
-- SHARE ROW EXCLUSIVE still allows reads but blocks other writers and blocks
-- a second copy of this script until this transaction finishes.
-- ============================================================================
LOCK TABLE customers, wallets, transactions, ledger_entries
    IN SHARE ROW EXCLUSIVE MODE;

-- ============================================================================
-- STAGE 1: Generation parameters (fixed values => reproducible dataset).
-- ============================================================================
CREATE TEMP TABLE p2_params ON COMMIT DROP AS
SELECT
    5000                                      AS n_customers,
    100000                                    AS n_transfers,
    250                                       AS n_hot_customers,     -- high-activity senders
    30                                        AS hot_share_pct,       -- % of transfers they send
    TIMESTAMPTZ '2025-01-01 08:00:00+01'      AS onboarding_start,    -- customers / deposits
    TIMESTAMPTZ '2025-07-01 00:00:00+01'      AS transfer_start,      -- first transfer
    100.00::NUMERIC(18,2)                     AS min_transfer,
    50000.00::NUMERIC(18,2)                   AS max_transfer;

-- ============================================================================
-- STAGE 2: Repeat-run guard and pre-conditions.
-- Rejects the run BEFORE any data change if the P2 dataset already exists,
-- or if the SYSTEM_CLEARING wallet is missing or not reconciled.
-- ============================================================================
DO $$
DECLARE
    v_count           BIGINT;
    v_clearing_id     BIGINT;
    v_clearing_bal    NUMERIC(18,2);
    v_clearing_ledger NUMERIC(18,2);
    v_last_entry_at   TIMESTAMPTZ;
BEGIN
    -- 2a. Any existing P2 synthetic rows => refuse to run again.
    SELECT
        (SELECT COUNT(*) FROM customers    WHERE email LIKE 'p2.customer.%@example.invalid')
      + (SELECT COUNT(*) FROM wallets      WHERE wallet_number LIKE 'P2W%')
      + (SELECT COUNT(*) FROM transactions WHERE reference LIKE 'P2-%')
    INTO v_count;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'P2 synthetic dataset already exists (% matching rows). Run rejected; no changes made.', v_count;
    END IF;

    -- 2b. Exactly one SYSTEM_CLEARING wallet must exist (it funds the deposits).
    SELECT COUNT(*) INTO v_count FROM wallets WHERE wallet_type = 'SYSTEM_CLEARING';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Expected exactly 1 SYSTEM_CLEARING wallet, found %.', v_count;
    END IF;

    SELECT wallet_id, balance INTO v_clearing_id, v_clearing_bal
    FROM wallets WHERE wallet_type = 'SYSTEM_CLEARING';

    -- 2c. The clearing wallet's cached balance must already match its ledger,
    --     because its new balance_after values continue from that balance.
    SELECT COALESCE(SUM(CASE WHEN entry_type = 'CREDIT' THEN amount ELSE -amount END), 0),
           MAX(created_at)
    INTO v_clearing_ledger, v_last_entry_at
    FROM ledger_entries WHERE wallet_id = v_clearing_id;

    IF v_clearing_bal <> v_clearing_ledger THEN
        RAISE EXCEPTION 'Clearing wallet % is not reconciled (cached %, ledger %).',
            v_clearing_id, v_clearing_bal, v_clearing_ledger;
    END IF;

    -- 2d. Existing clearing entries must pre-date the synthetic history so the
    --     chronological running balance remains valid.
    IF v_last_entry_at IS NOT NULL
       AND v_last_entry_at >= (SELECT onboarding_start FROM p2_params) THEN
        RAISE EXCEPTION 'Clearing wallet has ledger entries at or after the P2 history start (%).', v_last_entry_at;
    END IF;

    RAISE NOTICE 'Pre-checks passed. Clearing wallet id %, opening balance %.', v_clearing_id, v_clearing_bal;
END
$$;

-- ============================================================================
-- STAGE 3: Baseline snapshot of the existing data.
-- Used by the final checks to prove that pre-existing rows are unchanged.
-- ============================================================================
CREATE TEMP TABLE p2_base_customers    ON COMMIT DROP AS SELECT * FROM customers;
CREATE TEMP TABLE p2_base_wallets      ON COMMIT DROP AS SELECT * FROM wallets;
CREATE TEMP TABLE p2_base_transactions ON COMMIT DROP AS SELECT * FROM transactions;

CREATE TEMP TABLE p2_baseline ON COMMIT DROP AS
SELECT
    (SELECT COUNT(*) FROM customers)                           AS customers,
    (SELECT COUNT(*) FROM wallets)                             AS wallets,
    (SELECT COUNT(*) FROM transactions)                        AS transactions,
    (SELECT COUNT(*) FROM ledger_entries)                      AS ledger_entries,
    (SELECT COALESCE(SUM(balance), 0) FROM wallets)            AS total_balance;

-- Clearing wallet id and its opening balance (looked up, never assumed).
CREATE TEMP TABLE p2_clearing ON COMMIT DROP AS
SELECT wallet_id, balance AS opening_balance
FROM wallets
WHERE wallet_type = 'SYSTEM_CLEARING';

-- ============================================================================
-- STAGE 4: Customers.
-- Seed rows are built first, inserted with RETURNING, and the generated
-- customer_id values are mapped back to the seed sequence number via email.
-- Onboarding is spread 50 minutes apart from 2025-01-01 (ends ~2025-06-23).
-- ============================================================================
CREATE TEMP TABLE p2_customer_seed ON COMMIT DROP AS
SELECT
    g.seq,
    (ARRAY['Adaeze','Bolaji','Chinedu','Damilola','Emeka','Funmilayo','Gbenga','Halima',
           'Ifeoma','Jide','Kemi','Ladi','Musa','Ngozi','Oluwaseun','Precious',
           'Rasheed','Sade','Tunde','Uche'])[1 + (g.seq % 20)]                 AS first_name,
    (ARRAY['Adebayo','Bello','Chukwu','Danjuma','Eze','Fashola','Garba','Hassan',
           'Ibrahim','Johnson','Kalu','Lawal','Mohammed','Nwosu','Okafor','Okonkwo',
           'Olawale','Suleiman','Usman','Yusuf'])[1 + ((g.seq * 7) % 20)]      AS last_name,
    'p2.customer.' || LPAD(g.seq::TEXT, 5, '0') || '@example.invalid'          AS email,
    'P2-TEL-' || LPAD(g.seq::TEXT, 6, '0')                                     AS phone_number,
    p.onboarding_start + (g.seq - 1) * INTERVAL '50 minutes'                   AS created_at
FROM p2_params p
CROSS JOIN LATERAL generate_series(1, p.n_customers) AS g(seq);

-- Temp-table keys only (session staging); the KoraPay schema is not changed.
CREATE TEMP TABLE p2_customer_map (
    seq         INTEGER PRIMARY KEY,
    customer_id BIGINT  NOT NULL UNIQUE
) ON COMMIT DROP;

WITH ins AS (
    INSERT INTO customers
        (first_name, last_name, email, phone_number,
         verification_status, created_at, updated_at)
    SELECT first_name, last_name, email, phone_number,
           'VERIFIED', created_at, created_at
    FROM p2_customer_seed
    ORDER BY seq
    RETURNING customer_id, email
)
INSERT INTO p2_customer_map (seq, customer_id)
SELECT s.seq, ins.customer_id
FROM ins
JOIN p2_customer_seed s ON s.email = ins.email;

-- ============================================================================
-- STAGE 5: Customer wallets (one per new customer, opened 2 minutes after
-- onboarding with a zero balance). Generated wallet_id values are mapped back
-- to the seed sequence number via the unique wallet number.
-- ============================================================================
CREATE TEMP TABLE p2_wallet_map (
    seq           INTEGER PRIMARY KEY,
    wallet_id     BIGINT  NOT NULL UNIQUE,
    wallet_number VARCHAR(20) NOT NULL
) ON COMMIT DROP;

WITH ins AS (
    INSERT INTO wallets
        (customer_id, wallet_number, wallet_type, currency,
         balance, status, created_at, updated_at)
    SELECT cm.customer_id,
           'P2W' || LPAD(cm.seq::TEXT, 7, '0'),
           'CUSTOMER', 'NGN', 0.00, 'ACTIVE',
           s.created_at + INTERVAL '2 minutes',
           s.created_at + INTERVAL '2 minutes'
    FROM p2_customer_map cm
    JOIN p2_customer_seed s ON s.seq = cm.seq
    ORDER BY cm.seq
    RETURNING wallet_id, wallet_number
)
INSERT INTO p2_wallet_map (seq, wallet_id, wallet_number)
SELECT SUBSTRING(ins.wallet_number FROM 4)::INTEGER, ins.wallet_id, ins.wallet_number
FROM ins;

-- ============================================================================
-- STAGE 6: Transfer plan (deterministic, no random()).
--   x       : multiplicative hash of n modulo the prime 4294967291, giving a
--             reproducible pseudo-random spread.
--   sender  : hot_share_pct% of transfers come from the first n_hot_customers
--             (skewed, realistic activity); the rest spread over all customers.
--   receiver: sender + offset (1 .. n_customers-1) wrapped around, so the
--             receiver is always a different new customer wallet.
--   amount  : 70% small (100.00 - 5,000.00), 30% large (5,000.00 - 50,000.00).
--   time    : 315 s apart from 2025-07-01 plus 0-299 s jitter, so timestamps
--             vary yet are strictly increasing in n (ends ~2026-06-30).
-- ============================================================================
CREATE TEMP TABLE p2_transfer_plan ON COMMIT DROP AS
WITH g AS (
    SELECT n,
           (n::BIGINT * 2654435761) % 4294967291 AS x,
           (n::BIGINT * 48271)      % 2147483647 AS y
    FROM p2_params p
    CROSS JOIN LATERAL generate_series(1, p.n_transfers) AS n
),
s AS (
    SELECT g.n, g.x, g.y,
           CASE WHEN g.x % 100 < p.hot_share_pct
                THEN ((g.x / 100) % p.n_hot_customers) + 1
                ELSE ((g.x / 100) % p.n_customers) + 1
           END::INTEGER AS src_seq
    FROM g CROSS JOIN p2_params p
)
SELECT
    s.n,
    'P2-TRF-' || LPAD(s.n::TEXT, 6, '0')                                         AS reference,
    s.src_seq,
    (((s.src_seq - 1) + 1 + ((s.n::BIGINT * 40503 + 12345) % (p.n_customers - 1)))
        % p.n_customers + 1)::INTEGER                                            AS dst_seq,
    (CASE WHEN s.n % 10 < 7
          THEN 10000  + (s.y % 490001)        -- kobo: 100.00 .. 5,000.00
          ELSE 500000 + (s.y % 4500001)       -- kobo: 5,000.00 .. 50,000.00
     END / 100.0)::NUMERIC(18,2)                                                 AS amount,
    p.transfer_start + (s.n::BIGINT * 315 + (s.x % 300)) * INTERVAL '1 second'  AS created_at
FROM s CROSS JOIN p2_params p;

-- ============================================================================
-- STAGE 7: Funding plan.
-- Each wallet's deposit = (total of ALL its future outgoing transfers) plus a
-- small deterministic buffer. Because funding precedes every transfer and
-- ignores incoming money, the balance can never become negative at any point.
-- Deposits occur 10 minutes after onboarding, all before 2025-07-01.
-- ============================================================================
CREATE TEMP TABLE p2_funding ON COMMIT DROP AS
SELECT
    wm.seq,
    wm.wallet_id,
    'P2-DEP-' || LPAD(wm.seq::TEXT, 5, '0')                                      AS reference,
    (COALESCE(o.total_out, 0) + 1000.00 + (wm.seq % 10) * 500.00)::NUMERIC(18,2) AS amount,
    cs.created_at + INTERVAL '10 minutes'                                        AS created_at
FROM p2_wallet_map wm
JOIN p2_customer_seed cs ON cs.seq = wm.seq
LEFT JOIN (
    SELECT src_seq, SUM(amount) AS total_out
    FROM p2_transfer_plan
    GROUP BY src_seq
) o ON o.src_seq = wm.seq;

-- ============================================================================
-- STAGE 8: Insert transactions (deposits, then transfers) and capture the
-- generated transaction_id values through RETURNING.
-- event_order gives one global chronological order:
--   deposits 1 .. n_customers, transfers n_customers + 1 .. n_customers + n_transfers.
-- ============================================================================
CREATE TEMP TABLE p2_txn_map (
    transaction_id BIGINT      PRIMARY KEY,
    reference      VARCHAR(64) NOT NULL UNIQUE,
    txn_kind       VARCHAR(20) NOT NULL,
    event_order    INTEGER     NOT NULL UNIQUE
) ON COMMIT DROP;

-- 8a. Funding deposits: SYSTEM_CLEARING -> new customer wallet.
WITH ins AS (
    INSERT INTO transactions
        (reference, transaction_type, source_wallet_id, destination_wallet_id,
         amount, status, description, created_at)
    SELECT f.reference, 'DEPOSIT', c.wallet_id, f.wallet_id,
           f.amount, 'SUCCESSFUL', 'P2 synthetic benchmark funding deposit', f.created_at
    FROM p2_funding f
    CROSS JOIN p2_clearing c
    ORDER BY f.seq
    RETURNING transaction_id, reference
)
INSERT INTO p2_txn_map (transaction_id, reference, txn_kind, event_order)
SELECT ins.transaction_id, ins.reference, 'DEPOSIT', f.seq
FROM ins
JOIN p2_funding f ON f.reference = ins.reference;

-- 8b. Customer-to-customer transfers between distinct new wallets.
WITH ins AS (
    INSERT INTO transactions
        (reference, transaction_type, source_wallet_id, destination_wallet_id,
         amount, status, description, created_at)
    SELECT tp.reference, 'TRANSFER', ws.wallet_id, wd.wallet_id,
           tp.amount, 'SUCCESSFUL', 'P2 synthetic benchmark transfer', tp.created_at
    FROM p2_transfer_plan tp
    JOIN p2_wallet_map ws ON ws.seq = tp.src_seq
    JOIN p2_wallet_map wd ON wd.seq = tp.dst_seq
    ORDER BY tp.n
    RETURNING transaction_id, reference
)
INSERT INTO p2_txn_map (transaction_id, reference, txn_kind, event_order)
SELECT ins.transaction_id, ins.reference, 'TRANSFER', p.n_customers + tp.n
FROM ins
JOIN p2_transfer_plan tp ON tp.reference = ins.reference
CROSS JOIN p2_params p;

ANALYZE p2_txn_map;

-- ============================================================================
-- STAGE 9: Ledger staging with chronological running balances.
-- Each transaction yields a DEBIT on its source wallet (money out) and a
-- CREDIT on its destination wallet (money in). balance_after is the wallet's
-- opening balance plus the cumulative signed amount, ordered by
-- (created_at, event_order). Opening balance: 0 for new wallets, the
-- reconciled cached balance for the clearing wallet (so it goes negative).
-- ============================================================================
CREATE TEMP TABLE p2_opening ON COMMIT DROP AS
SELECT wallet_id, 0.00::NUMERIC(18,2) AS opening_balance FROM p2_wallet_map
UNION ALL
SELECT wallet_id, opening_balance FROM p2_clearing;

CREATE TEMP TABLE p2_ledger_stage ON COMMIT DROP AS
WITH movements AS (
    SELECT t.transaction_id, t.source_wallet_id AS wallet_id, 'DEBIT' AS entry_type,
           t.amount, -t.amount AS signed_amount, t.created_at, m.event_order
    FROM p2_txn_map m JOIN transactions t ON t.transaction_id = m.transaction_id
    UNION ALL
    SELECT t.transaction_id, t.destination_wallet_id, 'CREDIT',
           t.amount, t.amount, t.created_at, m.event_order
    FROM p2_txn_map m JOIN transactions t ON t.transaction_id = m.transaction_id
)
SELECT
    mv.transaction_id, mv.wallet_id, mv.entry_type, mv.amount, mv.created_at, mv.event_order,
    (o.opening_balance
       + SUM(mv.signed_amount) OVER (
             PARTITION BY mv.wallet_id
             ORDER BY mv.created_at, mv.event_order
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))::NUMERIC(18,2) AS balance_after
FROM movements mv
JOIN p2_opening o ON o.wallet_id = mv.wallet_id;

-- ============================================================================
-- STAGE 10: Write ledger entries in chronological order (DEBIT before CREDIT
-- within each transaction) so ledger_entry_id also follows the history.
-- ============================================================================
INSERT INTO ledger_entries
    (transaction_id, wallet_id, entry_type, amount, balance_after, created_at)
SELECT transaction_id, wallet_id, entry_type, amount, balance_after, created_at
FROM p2_ledger_stage
ORDER BY event_order, entry_type DESC;   -- 'DEBIT' sorts after 'CREDIT', so DESC puts DEBIT first

-- ============================================================================
-- STAGE 11: Update cached wallet balances to the last ledger balance_after
-- for every new wallet and for the clearing wallet.
-- ============================================================================
UPDATE wallets w
SET balance    = f.balance_after,
    updated_at = f.created_at
FROM (
    SELECT DISTINCT ON (wallet_id) wallet_id, balance_after, created_at
    FROM p2_ledger_stage
    ORDER BY wallet_id, created_at DESC, event_order DESC
) f
WHERE w.wallet_id = f.wallet_id;

-- ============================================================================
-- STAGE 12: Verification before COMMIT.
-- Any failed check raises an exception, which aborts the whole transaction
-- so no partial dataset can be committed.
-- ============================================================================
DO $$
DECLARE
    p             RECORD;
    b             RECORD;
    v             BIGINT;
    v_num         NUMERIC;
    v_num2        NUMERIC;
    v_clearing_id BIGINT;
    v_opening     NUMERIC(18,2);
    n_txn         BIGINT;
BEGIN
    SELECT * INTO p FROM p2_params;
    SELECT * INTO b FROM p2_baseline;
    SELECT wallet_id, opening_balance INTO v_clearing_id, v_opening FROM p2_clearing;
    n_txn := p.n_customers + p.n_transfers;

    -- ---- 12.1 Row counts (table totals and P2-tagged rows) ------------------
    SELECT COUNT(*) INTO v FROM customers;
    IF v <> b.customers + p.n_customers THEN
        RAISE EXCEPTION 'Check 12.1 failed: customers = %, expected %.', v, b.customers + p.n_customers;
    END IF;

    SELECT COUNT(*) INTO v FROM wallets;
    IF v <> b.wallets + p.n_customers THEN
        RAISE EXCEPTION 'Check 12.1 failed: wallets = %, expected %.', v, b.wallets + p.n_customers;
    END IF;

    SELECT COUNT(*) INTO v FROM transactions;
    IF v <> b.transactions + n_txn THEN
        RAISE EXCEPTION 'Check 12.1 failed: transactions = %, expected %.', v, b.transactions + n_txn;
    END IF;

    SELECT COUNT(*) INTO v FROM ledger_entries;
    IF v <> b.ledger_entries + 2 * n_txn THEN
        RAISE EXCEPTION 'Check 12.1 failed: ledger_entries = %, expected %.', v, b.ledger_entries + 2 * n_txn;
    END IF;

    SELECT COUNT(*) INTO v FROM p2_customer_map;
    IF v <> p.n_customers THEN
        RAISE EXCEPTION 'Check 12.1 failed: % customer ids captured, expected %.', v, p.n_customers;
    END IF;

    SELECT COUNT(*) INTO v FROM p2_wallet_map;
    IF v <> p.n_customers THEN
        RAISE EXCEPTION 'Check 12.1 failed: % wallet ids captured, expected %.', v, p.n_customers;
    END IF;

    SELECT COUNT(*) INTO v FROM transactions
    WHERE reference LIKE 'P2-DEP-%' AND transaction_type = 'DEPOSIT' AND status = 'SUCCESSFUL';
    IF v <> p.n_customers THEN
        RAISE EXCEPTION 'Check 12.1 failed: % successful P2 deposits, expected %.', v, p.n_customers;
    END IF;

    SELECT COUNT(*) INTO v FROM transactions
    WHERE reference LIKE 'P2-TRF-%' AND transaction_type = 'TRANSFER' AND status = 'SUCCESSFUL';
    IF v <> p.n_transfers THEN
        RAISE EXCEPTION 'Check 12.1 failed: % successful P2 transfers, expected %.', v, p.n_transfers;
    END IF;

    -- ---- 12.2 Balanced double entry: exactly one DEBIT on the source and
    --           one CREDIT on the destination, each equal to the amount ------
    SELECT COUNT(*) INTO v
    FROM (
        SELECT t.transaction_id
        FROM p2_txn_map m
        JOIN transactions t       ON t.transaction_id  = m.transaction_id
        LEFT JOIN ledger_entries le ON le.transaction_id = t.transaction_id
        GROUP BY t.transaction_id, t.source_wallet_id, t.destination_wallet_id, t.amount
        HAVING COUNT(le.ledger_entry_id) <> 2
            OR COUNT(*) FILTER (WHERE le.entry_type = 'DEBIT'
                                  AND le.wallet_id  = t.source_wallet_id
                                  AND le.amount     = t.amount) <> 1
            OR COUNT(*) FILTER (WHERE le.entry_type = 'CREDIT'
                                  AND le.wallet_id  = t.destination_wallet_id
                                  AND le.amount     = t.amount) <> 1
    ) bad;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.2 failed: % P2 transactions without one matching DEBIT and CREDIT.', v;
    END IF;

    SELECT COALESCE(SUM(le.amount) FILTER (WHERE le.entry_type = 'DEBIT'), 0),
           COALESCE(SUM(le.amount) FILTER (WHERE le.entry_type = 'CREDIT'), 0)
    INTO v_num, v_num2
    FROM ledger_entries le
    JOIN p2_txn_map m ON m.transaction_id = le.transaction_id;
    IF v_num <> v_num2 THEN
        RAISE EXCEPTION 'Check 12.2 failed: P2 debits % <> P2 credits %.', v_num, v_num2;
    END IF;

    -- Ledger rows carry the same timestamp as their transaction.
    SELECT COUNT(*) INTO v
    FROM ledger_entries le
    JOIN p2_txn_map m   ON m.transaction_id = le.transaction_id
    JOIN transactions t ON t.transaction_id = le.transaction_id
    WHERE le.created_at <> t.created_at;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.2 failed: % ledger rows with a timestamp different from their transaction.', v;
    END IF;

    -- ---- 12.3 Wallet routing ------------------------------------------------
    -- Deposits: clearing wallet -> a new P2 customer wallet.
    SELECT COUNT(*) INTO v
    FROM p2_txn_map m
    JOIN transactions t ON t.transaction_id = m.transaction_id
    WHERE m.txn_kind = 'DEPOSIT'
      AND (t.source_wallet_id <> v_clearing_id
           OR t.destination_wallet_id NOT IN (SELECT wallet_id FROM p2_wallet_map));
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.3 failed: % deposits not routed clearing -> P2 wallet.', v;
    END IF;

    -- Every new wallet received exactly one funding deposit.
    SELECT COUNT(*) INTO v
    FROM p2_wallet_map wm
    LEFT JOIN (
        SELECT t.destination_wallet_id AS wallet_id, COUNT(*) AS deposits
        FROM p2_txn_map m
        JOIN transactions t ON t.transaction_id = m.transaction_id
        WHERE m.txn_kind = 'DEPOSIT'
        GROUP BY t.destination_wallet_id
    ) d ON d.wallet_id = wm.wallet_id
    WHERE COALESCE(d.deposits, 0) <> 1;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.3 failed: % P2 wallets without exactly one deposit.', v;
    END IF;

    -- Transfers: distinct new P2 customer wallets only (never clearing or P1 wallets).
    SELECT COUNT(*) INTO v
    FROM p2_txn_map m
    JOIN transactions t ON t.transaction_id = m.transaction_id
    WHERE m.txn_kind = 'TRANSFER'
      AND (t.source_wallet_id      NOT IN (SELECT wallet_id FROM p2_wallet_map)
           OR t.destination_wallet_id NOT IN (SELECT wallet_id FROM p2_wallet_map)
           OR t.source_wallet_id = t.destination_wallet_id);
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.3 failed: % transfers not between distinct P2 wallets.', v;
    END IF;

    -- ---- 12.4 Amounts -------------------------------------------------------
    SELECT COUNT(*) INTO v
    FROM p2_txn_map m
    JOIN transactions t ON t.transaction_id = m.transaction_id
    WHERE t.amount <= 0
       OR t.amount <> ROUND(t.amount, 2)
       OR (m.txn_kind = 'TRANSFER' AND t.amount NOT BETWEEN p.min_transfer AND p.max_transfer);
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.4 failed: % P2 transactions with invalid amounts.', v;
    END IF;

    -- Funding rule: each deposit covers all of that wallet's outgoing transfers.
    SELECT COUNT(*) INTO v
    FROM p2_wallet_map wm
    JOIN p2_txn_map m   ON m.txn_kind = 'DEPOSIT'
    JOIN transactions d ON d.transaction_id = m.transaction_id
                       AND d.destination_wallet_id = wm.wallet_id
    LEFT JOIN (
        SELECT t.source_wallet_id AS wallet_id, SUM(t.amount) AS total_out
        FROM p2_txn_map tm
        JOIN transactions t ON t.transaction_id = tm.transaction_id
        WHERE tm.txn_kind = 'TRANSFER'
        GROUP BY t.source_wallet_id
    ) o ON o.wallet_id = wm.wallet_id
    WHERE d.amount < COALESCE(o.total_out, 0);
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.4 failed: % wallets funded below their total outgoing transfers.', v;
    END IF;

    -- ---- 12.5 Running balances recomputed from the stored ledger ------------
    SELECT COUNT(*) INTO v
    FROM (
        SELECT le.wallet_id, le.balance_after,
               o.opening_balance
                 + SUM(CASE WHEN le.entry_type = 'CREDIT' THEN le.amount ELSE -le.amount END)
                   OVER (PARTITION BY le.wallet_id
                         ORDER BY le.created_at, le.ledger_entry_id
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS expected
        FROM ledger_entries le
        JOIN p2_txn_map m ON m.transaction_id = le.transaction_id
        JOIN p2_opening o ON o.wallet_id      = le.wallet_id
    ) r
    WHERE r.balance_after <> r.expected;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.5 failed: % ledger rows with an incorrect running balance_after.', v;
    END IF;

    -- No customer balance is negative at any point in the generated history.
    SELECT COUNT(*) INTO v
    FROM ledger_entries le
    JOIN p2_wallet_map wm ON wm.wallet_id = le.wallet_id
    WHERE le.balance_after < 0;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.5 failed: % customer ledger rows with a negative balance_after.', v;
    END IF;

    -- ---- 12.6 Cached-balance reconciliation ---------------------------------
    -- New wallets and the clearing wallet: cached balance must equal both the
    -- net ledger sum over ALL its entries and its last balance_after.
    SELECT COUNT(*) INTO v
    FROM p2_opening o
    JOIN wallets w ON w.wallet_id = o.wallet_id
    LEFT JOIN (
        SELECT wallet_id,
               SUM(CASE WHEN entry_type = 'CREDIT' THEN amount ELSE -amount END) AS net_ledger
        FROM ledger_entries
        GROUP BY wallet_id
    ) n ON n.wallet_id = o.wallet_id
    LEFT JOIN (
        SELECT DISTINCT ON (wallet_id) wallet_id, balance_after
        FROM ledger_entries
        ORDER BY wallet_id, created_at DESC, ledger_entry_id DESC
    ) l ON l.wallet_id = o.wallet_id
    WHERE w.balance IS DISTINCT FROM COALESCE(n.net_ledger, 0)
       OR w.balance IS DISTINCT FROM l.balance_after
       OR (w.wallet_type = 'CUSTOMER' AND w.balance < 0);
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.6 failed: % wallets whose cached balance does not reconcile to the ledger.', v;
    END IF;

    -- Clearing wallet = opening balance minus total funding (negative when the
    -- opening balance was zero).
    SELECT w.balance INTO v_num FROM wallets w WHERE w.wallet_id = v_clearing_id;
    SELECT v_opening - SUM(amount) INTO v_num2 FROM p2_funding;
    IF v_num <> v_num2 THEN
        RAISE EXCEPTION 'Check 12.6 failed: clearing balance % <> opening minus funding %.', v_num, v_num2;
    END IF;

    -- Money is conserved: deposits only move value out of clearing.
    SELECT COALESCE(SUM(balance), 0) INTO v_num FROM wallets;
    IF v_num <> b.total_balance THEN
        RAISE EXCEPTION 'Check 12.6 failed: total of all wallet balances changed from % to %.', b.total_balance, v_num;
    END IF;

    -- ---- 12.7 Pre-existing data preserved ------------------------------------
    -- Every baseline row must still exist with identical column values.
    SELECT COUNT(*) INTO v
    FROM (SELECT * FROM p2_base_customers EXCEPT SELECT * FROM customers) x;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.7 failed: % pre-existing customers changed.', v;
    END IF;

    -- The clearing wallet is excluded: its balance is intentionally updated.
    SELECT COUNT(*) INTO v
    FROM (SELECT * FROM p2_base_wallets WHERE wallet_id <> v_clearing_id
          EXCEPT
          SELECT * FROM wallets) x;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.7 failed: % pre-existing customer wallets changed.', v;
    END IF;

    SELECT COUNT(*) INTO v
    FROM (SELECT * FROM p2_base_transactions EXCEPT SELECT * FROM transactions) x;
    IF v <> 0 THEN
        RAISE EXCEPTION 'Check 12.7 failed: % pre-existing transactions changed (incl. the pending one).', v;
    END IF;

    SELECT COUNT(*) INTO v
    FROM ledger_entries le
    WHERE NOT EXISTS (SELECT 1 FROM p2_txn_map m WHERE m.transaction_id = le.transaction_id);
    IF v <> b.ledger_entries THEN
        RAISE EXCEPTION 'Check 12.7 failed: non-P2 ledger rows = %, expected %.', v, b.ledger_entries;
    END IF;

    RAISE NOTICE 'All checks passed: % customers, % wallets, % deposits, % transfers, % ledger entries added.',
        p.n_customers, p.n_customers, p.n_customers, p.n_transfers, 2 * n_txn;
END
$$;

-- ============================================================================
-- STAGE 13: Commit. Reached only if every check above passed; temp staging
-- tables are dropped automatically (ON COMMIT DROP).
-- ============================================================================
COMMIT;

-- ============================================================================
-- STAGE 14: Post-commit summary (read-only) for the evidence screenshot.
-- ============================================================================
SELECT
    current_database()                                                       AS database_name,
    (SELECT COUNT(*) FROM customers)                                         AS customers,
    (SELECT COUNT(*) FROM wallets)                                           AS wallets,
    (SELECT COUNT(*) FROM transactions)                                      AS transactions,
    (SELECT COUNT(*) FROM transactions WHERE reference LIKE 'P2-DEP-%')      AS p2_deposits,
    (SELECT COUNT(*) FROM transactions WHERE reference LIKE 'P2-TRF-%')      AS p2_transfers,
    (SELECT COUNT(*) FROM transactions WHERE status = 'PENDING')             AS pending_transactions,
    (SELECT COUNT(*) FROM ledger_entries)                                    AS ledger_entries,
    (SELECT balance FROM wallets WHERE wallet_type = 'SYSTEM_CLEARING')      AS clearing_balance,
    (SELECT SUM(balance) FROM wallets)                                       AS total_wallet_balance;
