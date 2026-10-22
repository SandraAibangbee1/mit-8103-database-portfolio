-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 2 — Query Optimisation
-- Query:        Q01 — Wallet statement (latest 50 ledger entries)
--
-- Business purpose:
--   Shows a customer their most recent wallet activity, as on a mobile app
--   "recent transactions" screen or a mini-statement. Each row is one ledger
--   movement on the wallet with its transaction reference, direction
--   (DEBIT = money out, CREDIT = money in), amount and running balance.
--   It is intended to support frequent wallet-history requests, so it is a
--   candidate for plan analysis. Actual workload frequency was not measured.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    w.wallet_number,
    le.ledger_entry_id,
    le.created_at        AS entry_created_at,
    t.reference          AS transaction_reference,
    t.transaction_type,
    le.entry_type,
    le.amount            AS entry_amount,
    le.balance_after
FROM wallets AS w
JOIN ledger_entries AS le
    ON le.wallet_id = w.wallet_id
JOIN transactions AS t
    ON t.transaction_id = le.transaction_id
WHERE w.wallet_number = 'P2W0000001'
ORDER BY
    le.created_at DESC,
    le.ledger_entry_id DESC
LIMIT 50;
