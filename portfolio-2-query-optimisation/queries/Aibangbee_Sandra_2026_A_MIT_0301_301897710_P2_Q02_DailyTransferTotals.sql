-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    2 — Query Optimisation
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_DailyTransferTotals.sql
-- Query:        Q02 — Daily successful transfer totals (June 2026)
--
-- Purpose:
--   Number and total value of successful transfers for each day of June 2026.
-- Notes:
--   * Reads transactions only, so each transfer is counted once. Joining
--     ledger_entries would double the totals (one DEBIT + one CREDIT each).
--   * The date range is applied to t.created_at itself, not to a converted
--     date, so an index on created_at can be used.
--   * Days are grouped by the Africa/Lagos calendar date.
-- ============================================================================
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
