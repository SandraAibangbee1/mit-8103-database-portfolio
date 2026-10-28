-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    2 — Query Optimisation
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_ExplainBefore.sql
-- Query:        Q03 — Top 10 sending wallets (June 2026), original version
--
-- Runs EXPLAIN (ANALYZE, BUFFERS) on the same query as
-- queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_TopSendingWallets.sql.
-- ANALYZE executes the query, which only reads data. Record the
-- "Execution Time" line at the bottom of the plan.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    w.wallet_number,
    COUNT(*)        AS transfer_count,
    SUM(t.amount)   AS total_sent
FROM transactions AS t
JOIN wallets AS w
    ON w.wallet_id = t.source_wallet_id
WHERE t.transaction_type = 'TRANSFER'
  AND t.status = 'SUCCESSFUL'
  AND t.created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+01'
  AND t.created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+01'
GROUP BY
    w.wallet_id,
    w.wallet_number
ORDER BY
    total_sent DESC,
    w.wallet_number ASC
LIMIT 10;
