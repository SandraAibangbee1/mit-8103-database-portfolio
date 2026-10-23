# Portfolio Milestone 3: Transactions and Concurrency

- **Student:** Sandra Aibangbee
- **Student ID:** 2026/A/MIT/0301/301897710
- **Course:** MIT 8103 Advanced Database Systems
- **Case study:** KoraPay Wallet (simulated Nigerian digital wallet platform)

---

## 1. Purpose

This portfolio demonstrates how PostgreSQL transactions protect KoraPay Wallet
money movements. Using dedicated Portfolio 3 test wallets, it records:

1. an **atomic successful transfer** (commit);
2. a **rollback** after a deliberate failure part-way through a transfer;
3. two **concurrent sessions** competing to spend from the same wallet under
   **READ COMMITTED**, with `SELECT ... FOR UPDATE` row locks preventing
   overspending;
4. **duplicate-reference rejection** by the `UNIQUE (reference)` constraint.

On the same P3 wallets it then adds:

5. a reusable **idempotent transfer function** with a same-transaction retry
   test and a **SAVEPOINT** recovery test (p3_09–p3_12).

Later experiments on separate lab records (p3_13 onwards) add:

6. a **lost update** and its prevention with a relative update (p3_14);
7. **READ COMMITTED versus REPEATABLE READ** with a retry after a concurrent
   change (p3_15);
8. a **deliberate deadlock** detected by PostgreSQL (p3_16);
9. an **unordered versus ordered locking** load test with pgbench (p3_17);
10. a **lock timeout** (p3_18) and **concurrent identical retries** of the
    transfer function (p3_19);
11. **final read-only integrity checks** (p3_20).

The results are explained in
[transactions-concurrency-analysis.md](transactions-concurrency-analysis.md).
All customers, wallets and transactions are fictional.

## 2. Database prerequisites

- **PostgreSQL 18.6** with **pgAdmin 4** (recorded in P3_01).
- The **`korapay_wallet`** database and the four tables created in
  [Portfolio 1](../portfolio-1-database-design/README.md).
- The Portfolio 2 synthetic dataset
  ([Portfolio 2](../portfolio-2-query-optimisation/README.md)). Before
  Portfolio 3 the database held 5,002 customers, 5,003 wallets, 105,001
  transactions and 210,000 ledger entries (P3_02).
- The single SYSTEM_CLEARING wallet (`wallet_id` 6, wallet number
  `0000000000`, ACTIVE), used to fund the Portfolio 3 test wallet (P3_03).

## 3. Folder guide

| Folder / file | Contents |
|---|---|
| [sql/](sql/) | Preflight, setup, demonstration and experiment scripts (`p3_01` to `p3_20`) |
| [screenshots/](screenshots/) | pgAdmin evidence for the recorded steps |
| [output/](output/) | Saved terminal output (p3_13 setup log, p3_17 pgbench results) |
| [transactions-concurrency-analysis.md](transactions-concurrency-analysis.md) | Explanation of the results, conclusions and limitations |

## 4. Portfolio 3 test records

Portfolio 3 uses its own records so that the Portfolio 2 benchmark data
(`P2W...`, `P2-...`) is not changed.

| Record | Identifier |
|---|---|
| Customers | `p3.customer.001`–`003@example.invalid`, phones `P3-TEL-000001`–`000003` |
| Wallets | `P3W0000001` (id 5009), `P3W0000002` (id 5010), `P3W0000003` (id 5011) |
| Transactions | `P3-DEP-001`, `P3-TRF-001`, `P3-CONC-001` (committed); `P3-FAIL-001` (rolled back); `P3-CONC-002` (validation-only label, never inserted) |

The only existing record changed by Portfolio 3 is the SYSTEM_CLEARING wallet,
which funded `P3W0000001` with NGN 10,000.00 through the `P3-DEP-001` deposit
and, in p3_13, the 20 lab wallets with 100,000.00 each.

Lab records created by p3_13:

| Record | Identifier |
|---|---|
| Lab customers and wallets | `p3lab.customer.001`–`020@example.invalid`, one wallet each: `P3LW000001`–`P3LW000020` |
| Lab funding deposits | `P3L-DEP-001`–`P3L-DEP-020` (balanced DEBIT/CREDIT pairs) |
| Lab schema | `p3_lab.accounts`, `p3_lab.transfer_log`, `p3_lab.setup_baseline` — not linked to the ledger; used for the deliberately unsafe experiments |

## 5. Scripts and their status

| Script | Purpose | Status of the SQL text |
|---|---|---|
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_01_preflight.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_01_preflight.sql) | Read-only environment, baseline and reconciliation checks | Executed as written (P3_01–P3_05, P3_07) |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql) | One-time creation and funding of the P3 wallets | Executed as written; result in P3_08 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_03_successful_transfer.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_03_successful_transfer.sql) | Demonstration 1: `P3-TRF-001` | Evidence A shown in P3_09; the after-transfer checks in P3_10 and P3_11 were ad-hoc queries, not the file's Evidence B–D |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_04_rollback.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_04_rollback.sql) | Demonstration 2: `P3-FAIL-001` | Executed section by section as written (P3_12–P3_18) |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_05_concurrency_session1.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_05_concurrency_session1.sql) | Demonstration 3: Session 1 | Written after the demonstration and aligned with P3_19, P3_22, P3_24 and P3_25. The start of the posting `DO` block is not visible in P3_25 and is **reconstructed** |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_06_concurrency_session2.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_06_concurrency_session2.sql) | Demonstration 3: Session 2 | Written after the demonstration and aligned with P3_20, P3_21, P3_23, P3_27 and P3_28 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_07_concurrency_observer.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_07_concurrency_observer.sql) | Demonstration 3: observer | Written after the demonstration and aligned with P3_26, P3_29, P3_30 and P3_32. The first five lines of the reconciliation query are not visible in P3_30 and are **reconstructed** |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_08_duplicate_reference.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_08_duplicate_reference.sql) | Demonstration 4: duplicate reference | Same statements as shown in P3_31 and P3_32 (line layout differs) |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_09_transfer_function.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_09_transfer_function.sql) | `public.korapay_transfer_funds` (idempotent transfer function) | Installed; P3_33 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_10_function_retry_test.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_10_function_retry_test.sql) | Same-transaction retry test (rolled back) | Run; P3_34, P3_35 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_11_post_commit_retry_test.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_11_post_commit_retry_test.sql) | Post-commit retry test | No screenshot or saved output; result not reported |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_12_savepoint_demo.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_12_savepoint_demo.sql) | SAVEPOINT recovery | Run; P3_39 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_13_lab_setup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_13_lab_setup.sql) | Lab wallets, funding and `p3_lab` schema | Executed; log in `output/` |
| […_p3_14_lost_update_session_a.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_14_lost_update_session_a.sql), […_session_b.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_14_lost_update_session_b.sql) | Lost update, unsafe and safe | Run; P3_40–P3_43 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_15_isolation_levels.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_15_isolation_levels.sql) | READ COMMITTED vs REPEATABLE READ | Run; P3_44, P3_46 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_16_deadlock_demo.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_16_deadlock_demo.sql) | Deliberate deadlock | Run; P3_47, P3_48 |
| [setup](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_17_benchmark_setup.sql), [unordered](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_17_unordered_workload.sql), [ordered](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_17_ordered_workload.sql) (p3_17) | pgbench lock-order comparison | Run; pgbench output in `output/`, P3_49 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_18_lock_timeout.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_18_lock_timeout.sql) | Lock timeout | Run; P3_50, P3_51 |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_19_concurrent_retry.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_19_concurrent_retry.sql) | Concurrent identical retries | Run; final verification reported only (P3_53 is a copy of P3_54) |
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_20_final_integrity_checks.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_20_final_integrity_checks.sql) | Final read-only integrity checks | Run; P3_54 |

> [!IMPORTANT]
> **Reconstructed SQL.** `p3_05`, `p3_06` and `p3_07` were written after the
> concurrency demonstration and then aligned with every statement visible in
> the screenshots. Lines that are not visible in any screenshot are marked
> `[Reconstructed]` in the files. For the executed SQL, the **screenshots
> P3_19–P3_32 are the authoritative record**.

## 6. Running the scripts in pgAdmin

- Run [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_01_preflight.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_01_preflight.sql) one check at a time.
- [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql) runs once as a whole script. It
  stops with an exception if any P3 record already exists.
- All other scripts must be run **section by section, never as a whole file**.
  Each script's header lists the order.
- Demonstration 3 needs **separate Query Tool tabs**: one for Session 1, one
  for Session 2 and one for the observer. Each tab is its own database session.
- After any error inside an open transaction, run `ROLLBACK;` before anything
  else in that tab.

> [!WARNING]
> The demonstrations have already been committed in the recorded database.
> `P3-TRF-001` and `P3-CONC-001` exist, so their posting sections must not be
> rerun there. Their opening-balance checks would fail, and the references are
> protected by `uq_transactions_reference`.

## 7. Evidence index

Screenshot files are in [screenshots/](screenshots/) and share the prefix
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_`.

### Preflight and setup

| # | Screenshot | What it shows |
|---|---|---|
| P3_01 | [Environment](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_01_Environment.png) | `korapay_wallet`, user `postgres`, PostgreSQL 18.6, isolation level read committed |
| P3_02 | [BaselineCounts](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_02_BaselineCounts.png) | 5,002 customers, 5,003 wallets, 105,001 transactions, 210,000 ledger entries |
| P3_03 | [ClearingWallet](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_03_ClearingWallet.png) | SYSTEM_CLEARING wallet 6, ACTIVE, balance −1,019,314,617.14 |
| P3_04 | [NoExistingP3Records](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_04_NoExistingP3Records.png) | No existing P3 customers, wallets or transactions (0 rows) |
| P3_05 | [NoExistingRoutines](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_05_NoExistingRoutines.png) | No user-defined functions in `public` (Check 5a, 0 rows) |
| P3_06 | *Not available* | The trigger check (5b) result was not captured |
| P3_07 | [BaselineReconciliation](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_07_BaselineReconciliation.png) | No wallet balance/ledger mismatches before Portfolio 3 (0 rows) |
| P3_08 | [SetupWallets](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_08_SetupWallets.png) | P3 wallets 10,000.00 / 0.00 / 0.00, ledger entries 1 / 0 / 0, all reconciled |

### Demonstration 1: atomic successful transfer

| # | Screenshot | What it shows |
|---|---|---|
| P3_09 | [TransferBefore](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_09_TransferBefore.png) | Opening balances 10,000.00 and 0.00 |
| P3_10 | [TransferAfter](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_10_TransferAfter.png) | Committed balances 9,000.00 and 1,000.00 |
| P3_11 | [TransferLedger](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_11_TransferLedger.png) | `P3-TRF-001`: DEBIT 1,000.00 (balance_after 9,000.00) and CREDIT 1,000.00 (balance_after 1,000.00) |

### Demonstration 2: rollback after a deliberate failure

| # | Screenshot | What it shows |
|---|---|---|
| P3_12 | [RollbackBefore](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_12_RollbackBefore.png) | Opening balances 9,000.00 and 1,000.00 |
| P3_13 | [RollbackDebitPending](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_13_RollbackDebitPending.png) | Locks on wallets 5009 and 5010; `P3-FAIL-001` (id 105008) PENDING; sender debited to 8,000.00, uncommitted |
| P3_14 | [RollbackUncommitted](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_RollbackUncommitted.png) | Inside the open transaction: PENDING transfer, sender balance 8,000.00 |
| P3_15 | [RollbackError](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_15_RollbackError.png) | Second DEBIT rejected: SQLSTATE 23505, `uq_ledger_entries_txn_entry_type`, key (105008, DEBIT) |
| P3_16 | [RollbackExecuted](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_16_RollbackExecuted.png) | `ROLLBACK` completed |
| P3_17 | [RollbackAfter](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_RollbackAfter.png) | Balances back to 9,000.00 and 1,000.00, ledger entries 2 and 1, both reconciled |
| P3_18 | [RollbackNoRecords](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_18_RollbackNoRecords.png) | `P3-FAIL-001`: 0 transactions, 0 ledger entries |

### Demonstration 3: concurrent sessions under READ COMMITTED

The locking test was run twice. In the first attempt, leftover pasted text
caused a syntax error in Session 1, which aborted its transaction and released
its locks. Both sessions were rolled back and the test was repeated
successfully. By their clock times, P3_22 and P3_23 were captured during the
first attempt and P3_24–P3_28 during the repeat, so no single lock-wait
duration is reported.

| # | Screenshot | What it shows |
|---|---|---|
| P3_19 | [Session1](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_19_Session1.png) | `P3_SESSION_1`, PID 39364, read committed |
| P3_20 | [Session2](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_20_Session2.png) | `P3_SESSION_2`, PID 41144, read committed |
| P3_21 | [ConcurrencyBefore](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_21_ConcurrencyBefore.png) | Opening balances 9,000.00 / 1,000.00 / 0.00 |
| P3_22 | [Session1Locks](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_22_Session1Locks.png) | Session 1: `BEGIN ISOLATION LEVEL READ COMMITTED`; wallets 5009 and 5010 locked `FOR UPDATE` (first attempt) |
| P3_23 | [Session2Waiting](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_23_Session2Waiting.png) | Session 2's `FOR UPDATE` on P3W0000001 and P3W0000003 waiting (first attempt) |
| P3_24 | [LockEvidence](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_24_LockEvidence.png) | From Session 1: PID 41144 waiting on `Lock`, `blocked_by` {39364} |
| P3_25 | [TransferUncommitted](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_25_TransferUncommitted.png) | `P3-CONC-001 posted but NOT committed. Sender: 1000.00, recipient: 9000.00` |
| P3_26 | [ObserverBeforeCommit](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_26_ObserverBeforeCommit.png) | Observer sees 9,000.00 / 1,000.00 and `visible_transfer_count` 0 |
| P3_27 | [Session2AfterWait](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_27_Session2AfterWait.png) | After Session 1 commits, Session 2's lock query returns P3W0000001 = 1,000.00 |
| P3_28 | [InsufficientFunds](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_28_InsufficientFunds.png) | `Transfer P3-CONC-002 rejected: insufficient funds. Available: 1000.00, required: 8000.00` (SQLSTATE P0001) |
| P3_29 | [ObserverAfterCommit](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_29_ObserverAfterCommit.png) | Observer sees 1,000.00 / 9,000.00 and `visible_transfer_count` 1 |
| P3_30 | [ConcurrencyReconciliation](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_30_ConcurrencyReconciliation.png) | Final 1,000.00 / 9,000.00 / 0.00, ledger entries 3 / 2 / 0, all reconciled |

### Demonstration 4: duplicate-reference rejection

| # | Screenshot | What it shows |
|---|---|---|
| P3_31 | [DuplicateReferenceRejected](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_31_DuplicateReferenceRejected.png) | Reusing `P3-CONC-001`: SQLSTATE 23505, `uq_transactions_reference` |
| P3_32 | [FinalTransferVerification](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_32_FinalTransferVerification.png) | Only `P3-CONC-001` exists: 8,000.00, SUCCESSFUL, 2 ledger entries |

### Transfer function, retries, SAVEPOINT and lost update (p3_09–p3_14)

| # | Screenshot | What it shows |
|---|---|---|
| P3_33 | [TransferFunctionCreated](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_33_TransferFunctionCreated.png) | p3_09 in psql: `CREATE FUNCTION`; `korapay_transfer_funds(…)` returns `bigint`, `plpgsql`, not SECURITY DEFINER, `search_path=pg_catalog, public` |
| P3_34 | [FunctionRetrySameID](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_34_FunctionRetrySameID.png) | p3_10: both calls returned 105011; `ids_match` = t |
| P3_35 | [FunctionRetryRollback](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_35_FunctionRetryRollback.png) | p3_10 after ROLLBACK: 0 transaction and 0 ledger rows; PASS notice |
| P3_36–P3_38 | *Not present* | No screenshot of p3_11 (post-commit retry) |
| P3_39 | [SavepointCommitted](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_39_SavepointCommitted.png) | p3_12: P3W0000001 998.00 (5 entries) and P3W0000002 9,002.00 (4 entries), reconciled; "all assertions passed" |
| P3_40 | [LostUpdateSessionB900](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_40_LostUpdateSessionB900.png) | p3_14 section A3a (Session A, despite the name): unsafe write returns 900.00 |
| P3_41 | [LostUpdateConfirmed](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_41_LostUpdateConfirmed.png) | p3_14 A4: balance 900.00, expected 800.00, `amount_lost` 100.00 |
| P3_42 | [SafeUpdateBlocking](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_42_SafeUpdateBlocking.png) | p3_14 A7: PID 12104 waiting on `Lock`, `blocked_by` {6416} |
| P3_43 | [SafeUpdateConfirmed](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_43_SafeUpdateConfirmed.png) | p3_14 B5: balance 800.00, `correct` = true, 0 open experiment transactions |

### Isolation levels, deadlock and load test (p3_15–p3_17)

| # | Evidence | What it shows |
|---|---|---|
| P3_44 | [ReadCommittedSecondRead](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_44_ReadCommittedSecondRead.png) | p3_15 step S5: Session B commits account 1 = 900.00 (despite its name, not Session A's second read) |
| P3_46 | [RepeatableReadRetry800](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_46_RepeatableReadRetry800.png) | p3_15 step S14: REPEATABLE READ retry returns 800.00 |
| P3_47 | [DeadlockDetected](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_47_DeadlockDetected.png) | p3_16: Session B receives `deadlock detected`, SQLSTATE 40P01 |
| P3_48 | [DeadlockBalancesUnchanged](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_48_DeadlockBalancesUnchanged.png) | p3_16: accounts 1 and 2 at 800.00 / 1,000.00; no open experiment transactions |
| — | [pgbench unordered](output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_17_pgbench_unordered.txt) | 1979/2000 processed; 21 deadlock failures |
| — | [pgbench ordered](output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_17_pgbench_ordered.txt) | 2000/2000 processed; 0 failures |
| P3_49 | [PgbenchIntegrityConfirmed](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_49_PgbenchIntegrityConfirmed.png) | After both runs: 0 negative balances; log rows 1979 unordered and 2000 ordered |

The two pgbench output files are UTF-16 text (saved by a PowerShell redirect).

### Lock timeout, concurrent retries and final checks (p3_18–p3_20)

| # | Evidence | What it shows |
|---|---|---|
| P3_50 | [LockTimeout](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_50_LockTimeout.png) | p3_18: `canceling statement due to lock timeout`, SQLSTATE 55P03, after 00:00:03.094 |
| P3_51 | [LockTimeoutVerified](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_51_LockTimeoutVerified.png) | p3_18: account 3 = 100,016.00 with an earlier `updated_at`; `lock_timeout` 0; 0 open experiment transactions |
| P3_53 | [ConcurrentRetryVerified](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_53_ConcurrentRetryVerified.png) | Identical to P3_54 (shows the p3_20 checks, not p3_19). p3_19 final verification is reported only: `P3L-RETRY-COMMIT-001` = 105037 and `P3L-RETRY-ROLLBACK-001` = 105040, both SUCCESSFUL, 1.00, 2 ledger entries |
| P3_54 | [FinalIntegrityChecks](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_54_FinalIntegrityChecks.png) | p3_20: 12 result rows; checks 1–5 visible, all `pass = true` (all 12 reported as passing) |

## 8. Limitations

- **Isolation levels.** READ COMMITTED and REPEATABLE READ were used;
  SERIALIZABLE was not tested. The p3_15 READ COMMITTED second read (S6) and
  the REPEATABLE READ serialization error (S12) were not captured as
  screenshots.
- **p3_19 and p3_20 evidence.** P3_53 is a byte-identical copy of P3_54 and
  shows the p3_20 result, so the p3_19 verification figures are reported
  only; the waiting and returned-ID steps were not captured. P3_54 shows only
  checks 1–5 of p3_20; checks 6–12 are reported as passing.
- **p3_09–p3_14 evidence.** p3_11 has no screenshot or saved output. P3_33
  does not show the function body, and P3_39 does not show the deliberate
  SAVEPOINT error. For p3_14, the initial reads, Session B's unsafe write and
  Session B's 800.00 result were not captured; P3_40 shows Session A's
  section A3a despite its name.
- **Session 2 was validation only.** It locked the wallets and checked the
  balance. No second transfer was posted and no second posting routine was
  executed.
- **Duplicate-request protection in Demonstrations 1–4.** There, the unique
  reference only blocks a second transaction with the same reference. The
  later p3_09 function adds retry handling, tested concurrently in p3_19.
- **Reconstructed SQL.** Parts of `p3_05` and `p3_07` that are not visible in
  any screenshot are reconstructed (see Section 5).
- **Missing screenshots.** P3_06 (the trigger check) is not available, so no
  trigger result is reported. Some executed steps have no screenshot of their
  own:
  - the `Messages` output of the `P3-TRF-001` transfer block (its committed
    result is shown in P3_10 and P3_11);
  - Session 1's `COMMIT` (its effect is shown in P3_27 and P3_29);
  - Session 2's `ROLLBACK` (later outputs are consistent with it: P3_30, P3_32);
  - the `ROLLBACK` after the duplicate-reference error (P3_32 shows the
    resulting state).

  These commands were executed; only their own messages were not captured.
  P3_10 and P3_11 are ad-hoc queries rather than the script's Evidence B–D.
- **Posting routine and permissions.** Demonstrations 1–4 posted in
  transaction blocks and `DO` blocks. The p3_09 function runs with the
  caller's privileges; the `SECURITY DEFINER` routine and permission model
  proposed in Portfolio 1 were not implemented.
- **Load test scope.** p3_17 ran each variant once on the lab table. Deadlock
  detection time affects its latency and TPS figures, and no "before" check
  or visible total-balance result was saved.

## 9. AI assistance

ChatGPT and Claude assisted with SQL drafting, explanations and documentation
for this portfolio. I executed the SQL in pgAdmin and captured the screenshots.
