-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 2 — Query Optimisation
-- Query:        Q03 (optimised rewrite) — Top 10 sending wallets (June 2026)
--
-- Business purpose:
--   Same result as queries/q03_top_sending_wallets.sql: the 10 wallets that
--   sent the most money through successful transfers in June 2026.
--
-- Proposed optimisation (to be confirmed with EXPLAIN ANALYZE):
--   The original query joins every matching transfer to wallets and then
--   groups the joined rows. This version aggregates transactions first,
--   grouping by source_wallet_id inside a subquery, so only one row per
--   sending wallet is joined to wallets to look up its wallet_number.
--   The filters and timestamp boundaries are identical to the original.
--   LIMIT is applied only in the outer query, after the final ordering.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    w.wallet_number,
    s.transfer_count,
    s.total_sent
FROM (
    SELECT
        t.source_wallet_id,
        COUNT(*)      AS transfer_count,
        SUM(t.amount) AS total_sent
    FROM transactions AS t
    WHERE t.transaction_type = 'TRANSFER'
      AND t.status = 'SUCCESSFUL'
      AND t.created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+01'
      AND t.created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+01'
    GROUP BY t.source_wallet_id
) AS s
JOIN wallets AS w
    ON w.wallet_id = s.source_wallet_id
ORDER BY
    s.total_sent DESC,
    w.wallet_number ASC
LIMIT 10;
