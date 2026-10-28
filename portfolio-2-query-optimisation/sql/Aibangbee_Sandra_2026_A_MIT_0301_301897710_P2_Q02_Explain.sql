-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    2 — Query Optimisation
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_Explain.sql
-- Query:        Q02 — Daily successful transfer totals (June 2026)
--
-- Runs EXPLAIN (ANALYZE, BUFFERS) on the same query as
-- queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_DailyTransferTotals.sql.
-- Run before and after the Q02 index. ANALYZE executes the query, which only
-- reads data. Record the "Execution Time" line at the bottom of the plan.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    (t.created_at AT TIME ZONE 'Africa/Lagos')::DATE AS transfer_date,
    COUNT(*)                                         AS transfer_count,
    SUM(t.amount)                                    AS total_amount
FROM transactions AS t
WHERE t.transaction_type = 'TRANSFER'
  AND t.status = 'SUCCESSFUL'
  AND t.created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+01'
  AND t.created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+01'
GROUP BY (t.created_at AT TIME ZONE 'Africa/Lagos')::DATE
ORDER BY transfer_date ASC;
