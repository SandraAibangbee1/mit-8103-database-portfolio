-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    2 — Query Optimisation
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_TopSendingWalletsRewrite.sql
-- Query:        Q03 — Top 10 sending wallets (June 2026), rewritten version
--
-- Purpose:
--   Meant to return the same result as
--   Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_TopSendingWallets.sql.
--
-- The rewrite:
--   The original joins every matching transfer to wallets, then groups.
--   This version groups transfers by source_wallet_id first (in a subquery),
--   so only one row per sending wallet is joined to wallets.
--   Filters and timestamp boundaries are the same as the original. LIMIT is
--   applied only in the outer query, after the final ordering.
--   Recorded result: 6.644 ms -> 4.586 ms (see the performance analysis).
-- ============================================================================
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
