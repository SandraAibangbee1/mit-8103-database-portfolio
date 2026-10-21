-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 2 — Query Optimisation
-- Query:        Q02 — Daily successful transfer totals (June 2026)
--
-- Business purpose:
--   Gives operations and finance teams a day-by-day view of successful
--   customer transfers in June 2026 (number of transfers and total value),
--   for activity monitoring and daily reporting.
--   It reads transactions only, so each transfer is counted once; joining
--   ledger_entries would double the totals (one DEBIT + one CREDIT each).
--   The date range is applied directly to t.created_at (not to a converted
--   date) so that an index on created_at could support the filter.
--   Days are grouped by the local Africa/Lagos calendar date.
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
