-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    1 — Database Design and Modelling
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql
-- Description:  Creates the four KoraPay Wallet tables: customers, wallets,
--               transactions and ledger_entries.
--
-- Run once against an empty korapay_wallet schema. A second run fails
-- because the tables already exist.
--
-- What these constraints do NOT enforce (proposed in Portfolio 1):
-- 1. Balanced posting: they cannot require every successful transaction to
--    have exactly one DEBIT and one CREDIT of equal amount. That needs
--    posting logic (for example a PL/pgSQL function).
-- 2. Ledger immutability: an append-only ledger needs role permissions, with
--    direct writes to ledger_entries and wallets.balance revoked from the
--    application role.
-- 3. Safe retries: UNIQUE (reference) blocks duplicate references, but
--    comparing a retried request with the original is application logic.
-- 4. Reconciliation: wallets.balance is a stored copy of the ledger total, so
--    it must be checked against ledger_entries with a reconciliation query.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. customers: customer profiles and simulated KYC status.
-- ============================================================================
CREATE TABLE customers (
    customer_id         BIGSERIAL,
    first_name          VARCHAR(50)     NOT NULL,
    last_name           VARCHAR(50)     NOT NULL,
    email               VARCHAR(255)    NOT NULL,
    phone_number        VARCHAR(20)     NOT NULL,
    verification_status VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_customers PRIMARY KEY (customer_id),

    -- Email and phone number must each be unique.
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT uq_customers_phone_number UNIQUE (phone_number),

    CONSTRAINT chk_customers_verification_status CHECK (
        verification_status IN ('PENDING', 'VERIFIED', 'SUSPENDED')
    )
);

-- ============================================================================
-- 2. wallets: NGN wallets, including the single system clearing wallet.
-- ============================================================================
CREATE TABLE wallets (
    wallet_id           BIGSERIAL,
    customer_id         BIGINT          NULL,
    wallet_number       VARCHAR(20)     NOT NULL,
    wallet_type         VARCHAR(20)     NOT NULL DEFAULT 'CUSTOMER',
    currency            VARCHAR(3)      NOT NULL DEFAULT 'NGN',
    balance             NUMERIC(18,2)   NOT NULL DEFAULT 0.00,
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_wallets PRIMARY KEY (wallet_id),

    CONSTRAINT uq_wallets_wallet_number UNIQUE (wallet_number),

    -- At most one wallet per customer.
    CONSTRAINT uq_wallets_customer_id UNIQUE (customer_id),

    -- A customer cannot be deleted while their wallet exists.
    CONSTRAINT fk_wallets_customer FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_wallets_type CHECK (
        wallet_type IN ('CUSTOMER', 'SYSTEM_CLEARING')
    ),
    CONSTRAINT chk_wallets_currency CHECK (
        currency = 'NGN'
    ),
    CONSTRAINT chk_wallets_status CHECK (
        status IN ('ACTIVE', 'FROZEN', 'CLOSED')
    ),

    -- Customer wallets need an owner; the clearing wallet has none.
    CONSTRAINT chk_wallets_customer_ownership CHECK (
        (wallet_type = 'CUSTOMER' AND customer_id IS NOT NULL) OR
        (wallet_type = 'SYSTEM_CLEARING' AND customer_id IS NULL)
    ),

    -- Customer balances cannot go negative; the clearing wallet can.
    CONSTRAINT chk_wallets_balance CHECK (
        (wallet_type = 'CUSTOMER' AND balance >= 0) OR
        (wallet_type = 'SYSTEM_CLEARING')
    )
);

-- Only one system clearing wallet may exist.
CREATE UNIQUE INDEX uq_single_system_clearing_wallet
    ON wallets (wallet_type)
    WHERE wallet_type = 'SYSTEM_CLEARING';

-- ============================================================================
-- 3. transactions: one row per request, with its reference (idempotency key),
--    type, wallets, amount, status and any reversal link.
-- ============================================================================
CREATE TABLE transactions (
    transaction_id              BIGSERIAL,
    reference                   VARCHAR(64)     NOT NULL,
    transaction_type            VARCHAR(20)     NOT NULL,
    source_wallet_id            BIGINT          NOT NULL,
    destination_wallet_id       BIGINT          NOT NULL,
    amount                      NUMERIC(18,2)   NOT NULL,
    status                      VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    reversal_of_transaction_id  BIGINT          NULL,
    description                 VARCHAR(255)    NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_transactions PRIMARY KEY (transaction_id),

    -- Each request reference can be used once.
    CONSTRAINT uq_transactions_reference UNIQUE (reference),

    CONSTRAINT fk_transactions_source_wallet FOREIGN KEY (source_wallet_id)
        REFERENCES wallets (wallet_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_destination_wallet FOREIGN KEY (destination_wallet_id)
        REFERENCES wallets (wallet_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_reversal_of FOREIGN KEY (reversal_of_transaction_id)
        REFERENCES transactions (transaction_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transactions_type CHECK (
        transaction_type IN ('TRANSFER', 'DEPOSIT', 'WITHDRAWAL', 'REVERSAL')
    ),
    CONSTRAINT chk_transactions_status CHECK (
        status IN ('PENDING', 'SUCCESSFUL', 'FAILED', 'REVERSED')
    ),

    CONSTRAINT chk_transactions_amount CHECK (
        amount > 0
    ),

    -- A wallet cannot send money to itself.
    CONSTRAINT chk_transactions_distinct_wallets CHECK (
        source_wallet_id <> destination_wallet_id
    ),

    -- Only a REVERSAL links to an original transaction, it must have that
    -- link, and it cannot reverse itself.
    CONSTRAINT chk_transactions_reversal_rule CHECK (
        (transaction_type = 'REVERSAL' AND reversal_of_transaction_id IS NOT NULL AND reversal_of_transaction_id <> transaction_id) OR
        (transaction_type <> 'REVERSAL' AND reversal_of_transaction_id IS NULL)
    )
);

-- A transaction can be reversed at most once.
CREATE UNIQUE INDEX uq_single_reversal_per_transaction
    ON transactions (reversal_of_transaction_id)
    WHERE reversal_of_transaction_id IS NOT NULL;

-- ============================================================================
-- 4. ledger_entries: the double-entry journal. Each money movement is meant
--    to write one DEBIT (money out) and one CREDIT (money in), each with the
--    wallet's balance_after.
-- ============================================================================
CREATE TABLE ledger_entries (
    ledger_entry_id     BIGSERIAL,
    transaction_id      BIGINT          NOT NULL,
    wallet_id           BIGINT          NOT NULL,
    entry_type          VARCHAR(6)      NOT NULL,
    amount              NUMERIC(18,2)   NOT NULL,
    balance_after       NUMERIC(18,2)   NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ledger_entries PRIMARY KEY (ledger_entry_id),

    CONSTRAINT fk_ledger_entries_transaction FOREIGN KEY (transaction_id)
        REFERENCES transactions (transaction_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ledger_entries_wallet FOREIGN KEY (wallet_id)
        REFERENCES wallets (wallet_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_ledger_entries_entry_type CHECK (
        entry_type IN ('DEBIT', 'CREDIT')
    ),

    CONSTRAINT chk_ledger_entries_amount CHECK (
        amount > 0
    ),

    -- At most one DEBIT and one CREDIT per transaction.
    CONSTRAINT uq_ledger_entries_txn_entry_type UNIQUE (transaction_id, entry_type)
);

COMMIT;
