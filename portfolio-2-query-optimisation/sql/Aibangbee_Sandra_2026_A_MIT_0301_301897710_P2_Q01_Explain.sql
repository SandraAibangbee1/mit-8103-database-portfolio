-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    2 — Query Optimisation
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q01_Explain.sql
-- Query:        Q01 — Wallet statement (latest 50 ledger entries)
--
-- Runs EXPLAIN (ANALYZE, BUFFERS) on the same query as
-- queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q01_WalletStatement.sql.
-- Run before and after the Q01 index. ANALYZE executes the query, which only
-- reads data. Record the "Execution Time" line at the bottom of the plan.
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
