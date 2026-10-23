-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_17_ordered_workload.sql
-- Description:  pgbench custom script — ORDERED lock acquisition.
--               Each transaction moves 1.00 between two DIFFERENT random lab
--               accounts (IDs 1-20) via p3_lab.transfer_ordered.
--               No sleeps. Run with --max-tries=1 so failures are not retried.
--               Command: see ..._p3_17_benchmark_setup.sql (step 4).
-- Expected (prediction, not a result): no deadlock failures, because both
-- rows are always locked in ascending account_id order.
-- ============================================================================

\set from_id random(1, 20)
\set step random(1, 19)
\set to_id 1 + (:from_id - 1 + :step) % 20

BEGIN;
SELECT p3_lab.transfer_ordered(:from_id, :to_id, 1.00);
COMMIT;
