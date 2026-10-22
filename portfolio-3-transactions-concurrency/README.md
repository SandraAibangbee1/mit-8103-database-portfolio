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
| [sql/](sql/) | Preflight, setup and demonstration scripts (`p3_01` to `p3_08`) |
| [screenshots/](screenshots/) | pgAdmin evidence for every recorded step |
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
which funded `P3W0000001` with NGN 10,000.00 through the `P3-DEP-001` deposit.

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

## 8. Limitations

- **One isolation level.** Only READ COMMITTED was demonstrated. REPEATABLE
  READ and SERIALIZABLE were not tested.
- **Session 2 was validation only.** It locked the wallets and checked the
  balance. No second transfer was posted and no second posting routine was
  executed.
- **Duplicate-request protection, not full idempotency.** The unique
  reference blocks a second transaction with the same reference. A complete
  idempotent retry workflow (detecting the retry, comparing the request
  payload and returning the original result) was not implemented.
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
- **No stored posting routine.** Posting was done in transaction blocks and
  `DO` blocks. The `SECURITY DEFINER` posting procedure and the permission
  model proposed in Portfolio 1 were not implemented.

## 9. AI assistance

ChatGPT and Claude assisted with SQL drafting, explanations and documentation
for this portfolio. I executed the SQL in pgAdmin and captured the screenshots.
