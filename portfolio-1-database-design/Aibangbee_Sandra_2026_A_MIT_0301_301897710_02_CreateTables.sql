-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 1 — Database Design and Modelling
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql
-- Description:  DDL script to create the four core relational tables for
--               KoraPay Wallet: customers, wallets, transactions, ledger_entries.
--
-- IMPORTANT ARCHITECTURAL & GOVERNANCE NOTES:
-- 1. Balanced Posting: Foreign keys and check constraints establish relational
--    integrity and valid domains, but they CANNOT alone guarantee that every
--    successful transaction contains exactly two matching, balanced ledger
--    entries (one DEBIT, one CREDIT of equal amount). This is enforced by the
--    proposed controlled posting logic (e.g., PL/pgSQL posting stored procedure).
-- 2. Ledger Immutability: True append-only immutability requires database role
--    permissions (Principle of Least Privilege). In production, direct INSERT,
--    UPDATE, and DELETE privileges on `ledger_entries` and direct UPDATE on
--    `wallets.balance` are revoked from application roles, allowing modifications
--    exclusively through trusted posting routines (SECURITY DEFINER).
-- 3. Safe Retries & Idempotency: The UNIQUE(reference) constraint guarantees
--    uniqueness at the storage layer. Comparing request payloads upon retries
--    and handling unique conflicts without aborting the transaction session
--    are governed by the application transfer workflow.
-- 4. Balance Reconciliation: While `wallets.balance` is stored as a derived
--    value for O(1) balance lookups, periodic automated reconciliation queries
--    audit cached balances against net historical ledger sums.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Table: customers
-- Purpose: Stores individual and small-business customer profiles, contact
--          details, and simulated KYC verification status.
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

    -- Primary Key
    CONSTRAINT pk_customers PRIMARY KEY (customer_id),

    -- Candidate Keys (Unique Identifiers)
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT uq_customers_phone_number UNIQUE (phone_number),

    -- Allowed-value Domain Constraints
    CONSTRAINT chk_customers_verification_status CHECK (
        verification_status IN ('PENDING', 'VERIFIED', 'SUSPENDED')
    )
);

-- ============================================================================
-- 2. Table: wallets
-- Purpose: Stores digital wallets denominated strictly in Nigerian Naira (NGN),
--          including customer wallets and the single system clearing wallet.
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

    -- Primary Key
    CONSTRAINT pk_wallets PRIMARY KEY (wallet_id),

    -- Candidate Key
    CONSTRAINT uq_wallets_wallet_number UNIQUE (wallet_number),

    -- At most one wallet per customer
    CONSTRAINT uq_wallets_customer_id UNIQUE (customer_id),

    -- Foreign Key: Linked customer must not be deleted while their wallet exists
    CONSTRAINT fk_wallets_customer FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE RESTRICT,

    -- Allowed-value Domain Constraints
    CONSTRAINT chk_wallets_type CHECK (
        wallet_type IN ('CUSTOMER', 'SYSTEM_CLEARING')
    ),
    CONSTRAINT chk_wallets_currency CHECK (
        currency = 'NGN'
    ),
    CONSTRAINT chk_wallets_status CHECK (
        status IN ('ACTIVE', 'FROZEN', 'CLOSED')
    ),

    -- Customer vs. System Clearing Wallet Ownership Rule:
    -- Customer wallets require customer_id; the system clearing wallet requires NULL customer_id.
    CONSTRAINT chk_wallets_customer_ownership CHECK (
        (wallet_type = 'CUSTOMER' AND customer_id IS NOT NULL) OR
        (wallet_type = 'SYSTEM_CLEARING' AND customer_id IS NULL)
    ),

    -- Non-negative Balance Rule:
    -- Customer wallets must not have negative balances; the system clearing wallet may hold negative balances.
    CONSTRAINT chk_wallets_balance CHECK (
        (wallet_type = 'CUSTOMER' AND balance >= 0) OR
        (wallet_type = 'SYSTEM_CLEARING')
    )
);

-- Partial Unique Index: At most one system clearing wallet is allowed across the entire database.
CREATE UNIQUE INDEX uq_single_system_clearing_wallet
    ON wallets (wallet_type)
    WHERE wallet_type = 'SYSTEM_CLEARING';

-- ============================================================================
-- 3. Table: transactions
-- Purpose: Records business-level transaction requests, idempotency references,
--          movement types, and execution/reversal status.
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

    -- Primary Key
    CONSTRAINT pk_transactions PRIMARY KEY (transaction_id),

    -- Candidate Key: Unique client reference / idempotency key
    CONSTRAINT uq_transactions_reference UNIQUE (reference),

    -- Foreign Keys with ON DELETE RESTRICT
    CONSTRAINT fk_transactions_source_wallet FOREIGN KEY (source_wallet_id)
        REFERENCES wallets (wallet_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_destination_wallet FOREIGN KEY (destination_wallet_id)
        REFERENCES wallets (wallet_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_reversal_of FOREIGN KEY (reversal_of_transaction_id)
        REFERENCES transactions (transaction_id)
        ON DELETE RESTRICT,

    -- Allowed-value Domain Constraints
    CONSTRAINT chk_transactions_type CHECK (
        transaction_type IN ('TRANSFER', 'DEPOSIT', 'WITHDRAWAL', 'REVERSAL')
    ),
    CONSTRAINT chk_transactions_status CHECK (
        status IN ('PENDING', 'SUCCESSFUL', 'FAILED', 'REVERSED')
    ),

    -- Monetary Integrity: Transaction amounts must be strictly greater than zero
    CONSTRAINT chk_transactions_amount CHECK (
        amount > 0
    ),

    -- Routing Integrity: Source and destination wallets must be distinct
    CONSTRAINT chk_transactions_distinct_wallets CHECK (
        source_wallet_id <> destination_wallet_id
    ),

    -- Reversal Reference Integrity:
    -- A reversal reference is required IF AND ONLY IF transaction_type is 'REVERSAL'.
    -- Self-reversal is strictly prohibited.
    CONSTRAINT chk_transactions_reversal_rule CHECK (
        (transaction_type = 'REVERSAL' AND reversal_of_transaction_id IS NOT NULL AND reversal_of_transaction_id <> transaction_id) OR
        (transaction_type <> 'REVERSAL' AND reversal_of_transaction_id IS NULL)
    )
);

-- Partial Unique Index: An original transaction can be reversed at most once.
CREATE UNIQUE INDEX uq_single_reversal_per_transaction
    ON transactions (reversal_of_transaction_id)
    WHERE reversal_of_transaction_id IS NOT NULL;

-- ============================================================================
-- 4. Table: ledger_entries
-- Purpose: The immutable, double-entry financial journal. Every successful
--          fund movement generates balanced DEBIT (money out) and CREDIT
--          (money in) entries, capturing a balance_after snapshot.
-- ============================================================================
CREATE TABLE ledger_entries (
    ledger_entry_id     BIGSERIAL,
    transaction_id      BIGINT          NOT NULL,
    wallet_id           BIGINT          NOT NULL,
    entry_type          VARCHAR(6)      NOT NULL,
    amount              NUMERIC(18,2)   NOT NULL,
    balance_after       NUMERIC(18,2)   NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Primary Key
    CONSTRAINT pk_ledger_entries PRIMARY KEY (ledger_entry_id),

    -- Foreign Keys with ON DELETE RESTRICT
    CONSTRAINT fk_ledger_entries_transaction FOREIGN KEY (transaction_id)
        REFERENCES transactions (transaction_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ledger_entries_wallet FOREIGN KEY (wallet_id)
        REFERENCES wallets (wallet_id)
        ON DELETE RESTRICT,

    -- Allowed-value Domain Constraints
    CONSTRAINT chk_ledger_entries_entry_type CHECK (
        entry_type IN ('DEBIT', 'CREDIT')
    ),

    -- Monetary Integrity: Ledger movement amounts must be strictly positive
    CONSTRAINT chk_ledger_entries_amount CHECK (
        amount > 0
    ),

    -- Double-Entry Pair Integrity:
    -- At most one DEBIT and at most one CREDIT ledger entry per transaction
    CONSTRAINT uq_ledger_entries_txn_entry_type UNIQUE (transaction_id, entry_type)
);

COMMIT;
