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
[Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_TransactionsConcurrencyAnalysis.md](Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_TransactionsConcurrencyAnalysis.md).
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
| [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_TransactionsConcurrencyAnalysis.md](Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_TransactionsConcurrencyAnalysis.md) | Explanation of the results, conclusions and limitations |

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

## 5. Scripts and what the evidence shows

Script names: `Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_NN_Description.sql`. In the text, **p3_NN** means script NN and **P3_NN** means screenshot NN. These are separate number series: screenshot P3_17 is a rollback step, while script p3_17 is the pgbench test.

**Evidence** column:
- **Shown**: the result is in a screenshot or saved output file.
- **Partly shown**: some steps or rows are missing.
- **Not shown**: no screenshot or output was saved.

| Script | Purpose | How the SQL text relates to what was run | Evidence |
|---|---|---|---|
| […_P3_01_Preflight.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_01_Preflight.sql) | Read-only checks before any change | Run as written | Shown: P3_01–P3_05, P3_07. Trigger check (5b) not shown: no P3_06 |
| […_P3_02_Setup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_02_Setup.sql) | Create and fund the three P3 wallets (run once) | Run as written | Shown: P3_08 |
| […_P3_03_SuccessfulTransfer.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_03_SuccessfulTransfer.sql) | Demonstration 1: `P3-TRF-001` | Run as written | Shown: P3_09 (Evidence A). P3_10 and P3_11 are ad-hoc queries, not the file's Evidence B–D |
| […_P3_04_Rollback.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_04_Rollback.sql) | Demonstration 2: `P3-FAIL-001` | Run section by section as written | Shown: P3_12–P3_18 |
| […_P3_05_ConcurrencySession1.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_05_ConcurrencySession1.sql) | Demonstration 3: Session 1 | Written afterwards to match P3_19, P3_22, P3_24 and P3_25; the start of the posting `DO` block is **reconstructed** | Shown, except Session 1's `COMMIT` message |
| […_P3_06_ConcurrencySession2.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_06_ConcurrencySession2.sql) | Demonstration 3: Session 2 | Written afterwards to match P3_20, P3_21, P3_23, P3_27 and P3_28 | Shown, except Session 2's `ROLLBACK` message |
| […_P3_07_ConcurrencyObserver.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_07_ConcurrencyObserver.sql) | Demonstration 3: observer | Written afterwards to match P3_26, P3_29, P3_30 and P3_32; the first five lines of the reconciliation query are **reconstructed** | Shown |
| […_P3_08_DuplicateReference.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_08_DuplicateReference.sql) | Demonstration 4: duplicate reference | Same statements as P3_31 and P3_32 (layout differs) | Shown |
| […_P3_09_TransferFunction.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_09_TransferFunction.sql) | Creates `public.korapay_transfer_funds` | Run (psql) | Shown: P3_33 (creation and catalogue row; not the function body) |
| […_P3_10_FunctionRetryTest.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_10_FunctionRetryTest.sql) | Identical retry in the same transaction, then rollback | Run (psql) | Shown: P3_34, P3_35 |
| […_P3_11_PostCommitRetryTest.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_11_PostCommitRetryTest.sql) | Identical retry after the first call committed | Unknown whether run | **Not shown**: no screenshot or output |
| […_P3_12_SavepointDemo.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_12_SavepointDemo.sql) | SAVEPOINT recovery | Run (psql) | Partly shown: P3_39 shows the final checks, not the deliberate error |
| […_P3_13_LabSetup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_13_LabSetup.sql) | Lab wallets, funding and `p3_lab` schema | Run (psql) | Shown: log in `output/` |
| […_P3_14_LostUpdateSessionA.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_LostUpdateSessionA.sql), […_P3_14_LostUpdateSessionB.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_LostUpdateSessionB.sql) | Lost update, unsafe and safe | Run section by section | Partly shown: P3_40–P3_43 (initial reads and Session B's updates not shown) |
| […_P3_15_IsolationLevels.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_15_IsolationLevels.sql) | READ COMMITTED vs REPEATABLE READ | Run section by section | Partly shown: P3_44 (S5), P3_46 (S14). S6 and the S12 serialization error are not shown |
| […_P3_16_DeadlockDemo.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_16_DeadlockDemo.sql) | Deliberate deadlock | Run section by section | Shown: P3_47, P3_48 (opening values D3 not shown) |
| […_P3_17_BenchmarkSetup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_BenchmarkSetup.sql), […_P3_17_UnorderedWorkload.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_UnorderedWorkload.sql), […_P3_17_OrderedWorkload.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_OrderedWorkload.sql) | pgbench lock-order comparison | Run | Shown: both pgbench outputs in `output/`, P3_49. The before/after check logs named in the setup header were not saved |
| […_P3_18_LockTimeout.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_18_LockTimeout.sql) | Lock timeout | Run section by section | Shown: P3_50, P3_51 |
| […_P3_19_ConcurrentRetry.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_19_ConcurrentRetry.sql) | Two identical calls at the same time | Reported as run | **Not shown**: P3_53 is a copy of P3_54 (see Section 7) |
| […_P3_20_FinalIntegrityChecks.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_20_FinalIntegrityChecks.sql) | 12 read-only integrity checks | Run | Partly shown: P3_54 shows checks 1–5 only |

> [!IMPORTANT]
> **Reconstructed SQL.** p3_05, p3_06 and p3_07 were written after the concurrency demonstration, then aligned with every statement visible in the screenshots. Lines no screenshot shows are marked `[Reconstructed]`. For what was actually run, **screenshots P3_19–P3_32 are the record**.

## 6. Running the scripts

- **pgAdmin Query Tool:**
  - p3_01: one check at a time.
  - p3_02 and p3_20: the whole file once.
  - p3_03–p3_08 and p3_14–p3_18: **section by section, never the whole file**. Each header gives the order.
- **psql** (the files use `\gset` and `\echo`): p3_09–p3_13. Each header gives the command.
- **Command Prompt:** p3_17, using the commands in the setup script's header.
- **Separate tabs, one per session**, for p3_05–p3_07, p3_14–p3_16, p3_18 and p3_19. The cross-session order of steps is listed in each of those headers.
- After any error inside an open transaction, run `ROLLBACK;` before anything else in that tab.

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
| — | [pgbench unordered](output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_PgbenchUnordered.txt) | 1979/2000 processed; 21 deadlock failures |
| — | [pgbench ordered](output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_PgbenchOrdered.txt) | 2000/2000 processed; 0 failures |
| P3_49 | [PgbenchIntegrityConfirmed](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_49_PgbenchIntegrityConfirmed.png) | After both runs: 0 negative balances; log rows 1979 unordered and 2000 ordered |

The two pgbench output files are UTF-16 text (saved by a PowerShell redirect).

### Lock timeout, concurrent retries and final checks (p3_18–p3_20)

| # | Evidence | What it shows |
|---|---|---|
| P3_50 | [LockTimeout](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_50_LockTimeout.png) | p3_18: `canceling statement due to lock timeout`, SQLSTATE 55P03, after 00:00:03.094 |
| P3_51 | [LockTimeoutVerified](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_51_LockTimeoutVerified.png) | p3_18: account 3 = 100,016.00 with an earlier `updated_at`; `lock_timeout` 0; 0 open experiment transactions |
| P3_53 | `ConcurrentRetryVerified` (not linked: the file is untracked) | **Does not show p3_19.** Byte-for-byte copy of P3_54, so it shows the p3_20 checks. It is also untracked in Git. The p3_19 result has no saved evidence |
| P3_54 | [FinalIntegrityChecks](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_54_FinalIntegrityChecks.png) | p3_20: "Showing rows 1 to 12"; checks 1–5 visible, all `pass = true`. Checks 6–12 are not visible |

**Gaps in the numbering:** P3_06, P3_36–P3_38, P3_45 and P3_52 do not exist. The file `screenshots/…_p3_17_benchmark_setup.sql` (untracked) is actually a PNG of the p3_17 unordered-workload script with no result, so it is not evidence.

## 8. Limitations

The full list is in the [analysis, Section 14](Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_TransactionsConcurrencyAnalysis.md#14-limitations). In short:

- **No saved evidence:** the p3_19 concurrent retry, the p3_11 post-commit retry, the trigger check (P3_06), and p3_20 checks 6–12.
- **Not tested:** SERIALIZABLE; rejection of a reused reference with different request details; overspending on real wallets without `FOR UPDATE` (the lost update was shown on the lab table only).
- **Not implemented:** the `SECURITY DEFINER` posting routine and revoked privileges proposed in Portfolio 1 (the p3_09 function runs with the caller's privileges).
- **Reconstructed SQL:** parts of p3_05 and p3_07 (Section 5).
- **Single runs:** each demonstration and each pgbench variant was run once.

## 9. AI assistance

ChatGPT and Claude assisted with SQL drafting, explanations and documentation for this portfolio. I executed the SQL in pgAdmin and psql and captured the screenshots.

Claude later simplified the wording of this README, the analysis and the SQL comments, checked the documented results against the screenshots and output files, and renamed the Portfolio 3 files to the naming standard.
