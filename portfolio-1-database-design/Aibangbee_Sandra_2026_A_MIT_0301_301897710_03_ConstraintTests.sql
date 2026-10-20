-- KoraPay Wallet: Portfolio 1 constraint tests.
-- Run each test separately by highlighting its statement.
-- Invalid statements intentionally produce constraint errors.
-- Setup INSERT statements were already executed. Do not rerun them.
-- Wallet IDs in this recorded session: 4, 5 and 6.
-- Pending transaction ID: 3.
-- These tests verify schema constraints, not complete money posting.
INSERT INTO customers
    (first_name, last_name, email, phone_number)
VALUES
    ('Ada', 'Obi', 'ada.test@example.com', '08011111111'),
    ('Bola', 'Ade', 'bola.test@example.com', '08022222222')
RETURNING customer_id, first_name, email, verification_status;
-- Test 1: Duplicate email must be rejected.
INSERT INTO customers
    (first_name, last_name, email, phone_number)
VALUES
    ('Chi', 'Eze', 'ada.test@example.com', '08033333333');
	-- Test 2: Duplicate phone number must be rejected.
INSERT INTO customers
    (first_name, last_name, email, phone_number)
VALUES
    ('Chi', 'Eze', 'chi.test@example.com', '08011111111');
	-- Test 3: Invalid verification status must be rejected.
INSERT INTO customers
    (first_name, last_name, email, phone_number, verification_status)
VALUES
    ('Chi', 'Eze', 'chi.test@example.com', '08033333333', 'APPROVED');
	-- Test 4: Negative customer wallet balance must be rejected.
INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, balance)
VALUES
    (1, '2200000001', 'CUSTOMER', -100.00);
	-- Test 5: Nonexistent customer must be rejected.
INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, balance)
VALUES
    (999999, '2200000005', 'CUSTOMER', 0.00);
	-- Test 6: Customer wallet without an owner must be rejected.
INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, balance)
VALUES
    (NULL, '2200000006', 'CUSTOMER', 0.00);
	-- Valid setup: create two customer wallets and one clearing wallet.
INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, balance)
VALUES
    (1, '2200000001', 'CUSTOMER', 0.00),
    (2, '2200000002', 'CUSTOMER', 0.00),
    (NULL, '0000000000', 'SYSTEM_CLEARING', 0.00)
RETURNING wallet_id, customer_id, wallet_number, wallet_type, balance;
-- Test 7: A second wallet for the same customer must be rejected.
INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, balance)
VALUES
    (1, '2200000007', 'CUSTOMER', 0.00);
	-- Test 8: A second system clearing wallet must be rejected.
INSERT INTO wallets
    (customer_id, wallet_number, wallet_type, balance)
VALUES
    (NULL, '0000000008', 'SYSTEM_CLEARING', 0.00);
	-- Test 9: Zero transaction amount must be rejected.
INSERT INTO transactions
    (reference, transaction_type,
     source_wallet_id, destination_wallet_id, amount)
VALUES
    ('test09-zero-amount', 'TRANSFER', 4, 5, 0.00);
	-- Test 10: Transfer to the same wallet must be rejected.
INSERT INTO transactions
    (reference, transaction_type,
     source_wallet_id, destination_wallet_id, amount)
VALUES
    ('test10-same-wallet', 'TRANSFER', 4, 4, 100.00);
	-- Valid setup: a pending request only; no money moves.
INSERT INTO transactions
    (reference, transaction_type,
     source_wallet_id, destination_wallet_id, amount)
VALUES
    ('test-reference-001', 'TRANSFER', 4, 5, 100.00)
RETURNING transaction_id, reference, amount, status;
-- Test 11: Duplicate transaction reference must be rejected.
INSERT INTO transactions
    (reference, transaction_type,
     source_wallet_id, destination_wallet_id, amount)
VALUES
    ('test-reference-001', 'TRANSFER', 4, 5, 100.00);
	-- Test 12: A reversal without an original transaction must be rejected.
INSERT INTO transactions
    (reference, transaction_type,
     source_wallet_id, destination_wallet_id, amount)
VALUES
    ('test12-missing-original', 'REVERSAL', 5, 4, 100.00);
	-- Test 13: Invalid ledger entry type must be rejected.
INSERT INTO ledger_entries
    (transaction_id, wallet_id, entry_type, amount, balance_after)
VALUES
    (3, 4, 'OTHER', 100.00, 0.00);
	-- Test 14: Zero ledger amount must be rejected.
INSERT INTO ledger_entries
    (transaction_id, wallet_id, entry_type, amount, balance_after)
VALUES
    (3, 4, 'DEBIT', 0.00, 0.00);
	-- Test 15: A nonexistent transaction must be rejected.
INSERT INTO ledger_entries
    (transaction_id, wallet_id, entry_type, amount, balance_after)
VALUES
    (999999, 4, 'DEBIT', 100.00, 0.00);
	-- Test 16: A currency other than NGN must be rejected.
UPDATE wallets
SET currency = 'USD'
WHERE wallet_id = 4;
-- Verify the stored data after constraint testing.
SELECT
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM wallets) AS wallets,
    (SELECT COUNT(*) FROM transactions) AS transactions,
    (SELECT COUNT(*) FROM ledger_entries) AS ledger_entries,
    (SELECT COUNT(*) FROM wallets
     WHERE currency <> 'NGN') AS non_ngn_wallets,
    (SELECT SUM(balance) FROM wallets) AS total_wallet_balance;