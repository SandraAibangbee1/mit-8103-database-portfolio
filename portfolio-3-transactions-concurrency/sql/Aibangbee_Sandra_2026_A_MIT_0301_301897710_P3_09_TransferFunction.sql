-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_09_TransferFunction.sql
-- Description:  Reusable, idempotent wallet transfer function:
--                 public.korapay_transfer_funds(
--                     sender wallet number, recipient wallet number,
--                     amount, request reference) RETURNS BIGINT
--               It returns the transactions.transaction_id of the transfer.
--
-- WHAT THIS SCRIPT DOES:
--   Creates (or replaces) the function and shows its catalogue entry.
--   It contains NO test calls and moves no money.
--
-- HOW THE FUNCTION FITS THE SCHEMA (Portfolio 1, Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql):
--   * transactions.reference is UNIQUE (uq_transactions_reference) and is
--     used as the idempotency key.
--   * amount is NUMERIC(18,2) with CHECK (amount > 0) on transactions and
--     ledger_entries.
--   * Customer wallet balances must stay >= 0 (chk_wallets_balance).
--   * Exactly one DEBIT and one CREDIT per transaction is backed by
--     uq_ledger_entries_txn_entry_type.
--
-- TRANSACTION BEHAVIOUR:
--   The function never commits or rolls back and never catches errors. It
--   runs inside the caller's transaction (or, when called on its own in
--   autocommit mode, inside that single statement's transaction). Any
--   exception aborts the whole transfer, including the PENDING claim row.
--   It is designed for READ COMMITTED, the isolation level used in
--   Portfolio 3. Under REPEATABLE READ or SERIALIZABLE, a concurrent retry may
--   instead fail with a serialization error (SQLSTATE 40001) and must be
--   retried by the caller.
--
-- NOT INCLUDED:
--   This is not the SECURITY DEFINER posting routine with revoked direct
--   privileges proposed in Portfolio 1; it runs with the caller's privileges.
--
-- HOW TO RUN (pgAdmin Query Tool, connected to korapay_wallet):
--   Execute the whole script once (F5). Re-running it replaces the function
--   with the same definition.
-- ============================================================================


CREATE OR REPLACE FUNCTION public.korapay_transfer_funds(
    p_sender_wallet_number    VARCHAR,
    p_recipient_wallet_number VARCHAR,
    p_amount                  NUMERIC,
    p_reference               VARCHAR
)
RETURNS BIGINT
LANGUAGE plpgsql
-- Fixed search_path so table names always resolve to the KoraPay schema.
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_amount          NUMERIC(18,2);
    v_sender_id       BIGINT;
    v_recipient_id    BIGINT;
    v_transaction_id  BIGINT;
    v_existing        public.transactions%ROWTYPE;
    v_sender          public.wallets%ROWTYPE;
    v_recipient       public.wallets%ROWTYPE;
    v_sender_after    NUMERIC(18,2);
    v_recipient_after NUMERIC(18,2);
BEGIN
    -- ------------------------------------------------------------------------
    -- STEP 1: Validate the arguments.
    -- The function is not declared STRICT, so NULL arguments reach these
    -- checks and produce a clear error instead of a silent NULL result.
    -- Length limits on VARCHAR parameters are not enforced by PostgreSQL, so
    -- the 64-character reference limit is checked explicitly.
    -- ------------------------------------------------------------------------
    IF p_reference IS NULL OR btrim(p_reference) = '' THEN
        RAISE EXCEPTION 'Transfer rejected: a non-blank request reference is required.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF char_length(p_reference) > 64 THEN
        RAISE EXCEPTION 'Transfer rejected: request reference exceeds 64 characters.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_sender_wallet_number IS NULL OR btrim(p_sender_wallet_number) = ''
       OR p_recipient_wallet_number IS NULL OR btrim(p_recipient_wallet_number) = '' THEN
        RAISE EXCEPTION 'Transfer rejected: sender and recipient wallet numbers are required.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_sender_wallet_number = p_recipient_wallet_number THEN
        RAISE EXCEPTION 'Transfer rejected: sender and recipient must be different wallets.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_amount IS NULL THEN
        RAISE EXCEPTION 'Transfer rejected: amount is required.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- NUMERIC accepts the special values NaN, Infinity and -Infinity. They
    -- are rejected explicitly, before any arithmetic or comparison check and
    -- before the value is assigned to the NUMERIC(18,2) variable.
    IF p_amount IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC) THEN
        RAISE EXCEPTION 'Transfer rejected: amount % is not a finite number.', p_amount
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer rejected: amount must be greater than zero.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Reject values that would be rounded when stored as NUMERIC(18,2),
    -- e.g. 100.005. Values such as 100.50 or 100.500 are accepted unchanged.
    IF p_amount <> round(p_amount, 2) THEN
        RAISE EXCEPTION 'Transfer rejected: amount % has more than two decimal places.', p_amount
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_amount > 9999999999999999.99 THEN
        RAISE EXCEPTION 'Transfer rejected: amount % exceeds NUMERIC(18,2).', p_amount
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_amount := p_amount;

    -- ------------------------------------------------------------------------
    -- STEP 2: Resolve wallet numbers to wallet IDs (no locks yet).
    -- wallet_number is unique (uq_wallets_wallet_number) and wallet_id never
    -- changes, so this unlocked lookup is safe. Balances and statuses are
    -- read only after the locks in STEP 5.
    -- ------------------------------------------------------------------------
    SELECT wallet_id INTO v_sender_id
    FROM public.wallets
    WHERE wallet_number = p_sender_wallet_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transfer rejected: sender wallet % does not exist.', p_sender_wallet_number
            USING ERRCODE = 'no_data_found';
    END IF;

    SELECT wallet_id INTO v_recipient_id
    FROM public.wallets
    WHERE wallet_number = p_recipient_wallet_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transfer rejected: recipient wallet % does not exist.', p_recipient_wallet_number
            USING ERRCODE = 'no_data_found';
    END IF;

    -- ------------------------------------------------------------------------
    -- STEP 3: Claim the request reference (idempotency, part 1).
    -- The PENDING row is inserted first, as in Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_DatabaseDesign.md 7.3.
    -- ON CONFLICT ... DO NOTHING uses the unique constraint without raising an
    -- error, so the caller's transaction is never put into an aborted state
    -- by a duplicate reference.
    --
    -- Concurrent calls with the same reference: if another transaction has
    -- inserted this reference but not yet committed, PostgreSQL makes this
    -- INSERT WAIT until that transaction ends.
    --   * If it COMMITS, this INSERT does nothing and returns no row.
    --   * If it ROLLS BACK, this INSERT succeeds and this call continues as
    --     a new transfer.
    -- Only one call can ever own a given reference.
    -- ------------------------------------------------------------------------
    INSERT INTO public.transactions
        (reference, transaction_type, source_wallet_id, destination_wallet_id,
         amount, status, description)
    VALUES
        (p_reference, 'TRANSFER', v_sender_id, v_recipient_id,
         v_amount, 'PENDING', 'Wallet transfer posted by public.korapay_transfer_funds')
    ON CONFLICT ON CONSTRAINT uq_transactions_reference DO NOTHING
    RETURNING transaction_id INTO v_transaction_id;

    -- ------------------------------------------------------------------------
    -- STEP 4: The reference already exists (idempotency, part 2).
    -- Under READ COMMITTED this SELECT takes a new snapshot, so it sees the
    -- committed row that caused the conflict in STEP 3.
    --   * Same TRANSFER, same wallets, same amount, SUCCESSFUL
    --       -> return the original transaction_id; no money moves again.
    --   * Different type, wallets or amount -> reject (reference reuse).
    --   * Same request but any other status (e.g. PENDING, FAILED, REVERSED)
    --       -> reject; a retry must not complete or repeat it.
    -- ------------------------------------------------------------------------
    IF v_transaction_id IS NULL THEN
        SELECT * INTO v_existing
        FROM public.transactions
        WHERE reference = p_reference;

        IF NOT FOUND THEN
            -- Defensive: the conflicting row is not visible (for example under
            -- a stricter isolation level). The caller should retry.
            RAISE EXCEPTION 'Transfer rejected: reference % is in use but could not be read; retry the request.', p_reference
                USING ERRCODE = 'serialization_failure';
        END IF;

        IF v_existing.transaction_type <> 'TRANSFER'
           OR v_existing.source_wallet_id <> v_sender_id
           OR v_existing.destination_wallet_id <> v_recipient_id
           OR v_existing.amount <> v_amount THEN
            RAISE EXCEPTION 'Transfer rejected: reference % was already used for a different request (% of % from wallet % to wallet %).',
                p_reference, v_existing.transaction_type, v_existing.amount,
                v_existing.source_wallet_id, v_existing.destination_wallet_id
                USING ERRCODE = 'unique_violation';
        END IF;

        IF v_existing.status <> 'SUCCESSFUL' THEN
            RAISE EXCEPTION 'Transfer rejected: reference % already exists with status %; it cannot be completed by a retry.',
                p_reference, v_existing.status
                USING ERRCODE = 'unique_violation';
        END IF;

        -- Identical successful retry: return the original result.
        RETURN v_existing.transaction_id;
    END IF;

    -- ------------------------------------------------------------------------
    -- STEP 5: Lock both wallets in ascending wallet_id order.
    -- The row locks are taken in the ORDER BY order, so every call touching
    -- the same two wallets requests them in the same sequence
    -- (Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_DatabaseDesign.md 7.1). A competing transfer on either wallet waits
    -- here until this transaction ends.
    --
    -- Why FOR NO KEY UPDATE rather than FOR UPDATE:
    --   The STEP 3 INSERT runs before these locks. Its foreign-key checks on
    --   source_wallet_id and destination_wallet_id take FOR KEY SHARE locks
    --   on both wallet rows. FOR KEY SHARE does not conflict with
    --   FOR NO KEY UPDATE, but it does conflict with FOR UPDATE. With
    --   FOR UPDATE, two concurrent calls with different references could each
    --   hold KEY SHARE on a wallet the other needs to lock, and deadlock even
    --   though both lock in ascending wallet_id order.
    --   FOR NO KEY UPDATE is sufficient here: it still blocks other
    --   FOR NO KEY UPDATE / FOR UPDATE lockers and other writers of these rows,
    --   and this function only changes balance and updated_at, never a key
    --   column (wallet_id, wallet_number, customer_id). It is also the lock
    --   level PostgreSQL itself takes for such non-key UPDATEs.
    --
    -- Limits: ordered locking reduces wallet-lock deadlocks between calls of
    -- this function; it does not prevent every possible deadlock. Deadlocks
    -- can still occur, for example, when a caller already holds other locks,
    -- makes several transfers in one transaction, or updates wallets by other
    -- means. PostgreSQL then aborts one transaction (SQLSTATE 40P01) and the
    -- caller should retry with the SAME reference.
    -- ------------------------------------------------------------------------
    PERFORM 1
    FROM public.wallets
    WHERE wallet_id IN (v_sender_id, v_recipient_id)
    ORDER BY wallet_id
    FOR NO KEY UPDATE;

    -- Read the current rows only after the locks are held. Under READ
    -- COMMITTED these reads see the latest committed balances, including any
    -- transfer that committed while this call was waiting for a lock.
    SELECT * INTO STRICT v_sender
    FROM public.wallets
    WHERE wallet_id = v_sender_id;

    SELECT * INTO STRICT v_recipient
    FROM public.wallets
    WHERE wallet_id = v_recipient_id;

    -- ------------------------------------------------------------------------
    -- STEP 6: Validate the locked wallets.
    -- ------------------------------------------------------------------------
    IF v_sender.wallet_type <> 'CUSTOMER' OR v_recipient.wallet_type <> 'CUSTOMER' THEN
        RAISE EXCEPTION 'Transfer rejected: both wallets must be CUSTOMER wallets (sender %, recipient %).',
            v_sender.wallet_type, v_recipient.wallet_type;
    END IF;

    IF v_sender.status <> 'ACTIVE' OR v_recipient.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Transfer rejected: both wallets must be ACTIVE (sender %, recipient %).',
            v_sender.status, v_recipient.status;
    END IF;

    IF v_sender.currency <> 'NGN' OR v_recipient.currency <> 'NGN' THEN
        RAISE EXCEPTION 'Transfer rejected: both wallets must be NGN (sender %, recipient %).',
            v_sender.currency, v_recipient.currency;
    END IF;

    IF v_sender.balance < v_amount THEN
        RAISE EXCEPTION 'Transfer rejected: insufficient funds in wallet %. Available: %, required: %.',
            p_sender_wallet_number, v_sender.balance, v_amount;
    END IF;

    -- ------------------------------------------------------------------------
    -- STEP 7: Post the transfer atomically.
    -- Each UPDATE returns the resulting balance, which becomes that ledger
    -- entry's balance_after. All writes belong to the caller's transaction and
    -- become visible to other sessions together when it commits.
    -- ------------------------------------------------------------------------
    UPDATE public.wallets
    SET balance    = balance - v_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_sender_id
    RETURNING balance INTO v_sender_after;

    UPDATE public.wallets
    SET balance    = balance + v_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE wallet_id = v_recipient_id
    RETURNING balance INTO v_recipient_after;

    INSERT INTO public.ledger_entries
        (transaction_id, wallet_id, entry_type, amount, balance_after)
    VALUES
        (v_transaction_id, v_sender_id,    'DEBIT',  v_amount, v_sender_after),
        (v_transaction_id, v_recipient_id, 'CREDIT', v_amount, v_recipient_after);

    UPDATE public.transactions
    SET status = 'SUCCESSFUL'
    WHERE transaction_id = v_transaction_id;

    RETURN v_transaction_id;
END;
$$;


COMMENT ON FUNCTION public.korapay_transfer_funds(VARCHAR, VARCHAR, NUMERIC, VARCHAR) IS
    'KoraPay Portfolio 3: idempotent wallet-to-wallet transfer. Claims the unique reference, locks both wallets in wallet_id order, validates them, posts balanced DEBIT/CREDIT entries and returns the transaction_id. An identical successful retry returns the original transaction_id.';


-- ----------------------------------------------------------------------------
-- Read-only confirmation that the function exists (moves no money).
-- ----------------------------------------------------------------------------
SELECT
    p.oid::REGPROCEDURE                AS signature,
    pg_get_function_result(p.oid)      AS returns,
    l.lanname                          AS language,
    p.prosecdef                        AS security_definer,
    p.proconfig                        AS settings
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
JOIN pg_language  AS l ON l.oid = p.prolang
WHERE n.nspname = 'public'
  AND p.proname = 'korapay_transfer_funds';
