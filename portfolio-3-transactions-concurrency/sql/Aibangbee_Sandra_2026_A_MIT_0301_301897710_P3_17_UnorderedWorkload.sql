-- ============================================================================
-- Course:       MIT 8103 Advanced Database Systems
-- Student:      Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
-- Portfolio:    Milestone 3 — Transactions and Concurrency
-- File:         Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_UnorderedWorkload.sql
-- Description:  pgbench custom script — UNORDERED lock acquisition.
--               Each transaction moves 1.00 between two DIFFERENT random lab
--               accounts (IDs 1-20) via p3_lab.transfer_unordered.
--               No sleeps. Run with --max-tries=1 so failures are not retried.
--               Command: see ..._P3_17_BenchmarkSetup.sql (step 2).
-- Expected (predicted before the run; recorded result in the P3 analysis, Section 11): some transactions may fail with
-- deadlock_detected (40P01). Failed transactions roll back and are not logged.
-- ============================================================================

\set from_id random(1, 20)
\set step random(1, 19)
\set to_id 1 + (:from_id - 1 + :step) % 20

BEGIN;
SELECT p3_lab.transfer_unordered(:from_id, :to_id, 1.00);
COMMIT;
