SELECT
    current_database() AS database_name,
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM wallets) AS wallets,
    (SELECT COUNT(*) FROM transactions) AS transactions,
    (SELECT COUNT(*) FROM ledger_entries) AS ledger_entries,
    (SELECT SUM(balance) FROM wallets) AS total_wallet_balance;