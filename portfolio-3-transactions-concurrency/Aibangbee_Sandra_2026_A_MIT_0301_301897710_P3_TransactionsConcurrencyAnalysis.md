# Portfolio 3 — Transactions and Concurrency Analysis

- **Student:** Sandra Aibangbee (2026/A/MIT/0301/301897710)
- **Course:** MIT 8103 Advanced Database Systems
- **Environment:** PostgreSQL 18.6, pgAdmin 4, database `korapay_wallet`
- **Isolation levels used:** READ COMMITTED (Demonstrations 1–4, p3_14,
  p3_16, p3_17) and REPEATABLE READ (p3_15). SERIALIZABLE was not tested.

This document explains what each recorded demonstration shows. Screenshot
links point to [screenshots/](screenshots/). The scripts and the status of
their SQL text are listed in the [README](README.md#5-scripts-and-what-the-evidence-shows).

---

## 1. Starting point

### 1.1 Environment and baseline

The preflight checks ([Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_01_Preflight.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_01_Preflight.sql))
recorded the state of the database before any Portfolio 3 change:

| Check | Recorded result | Evidence |
|---|---|---|
| Database, user, version | `korapay_wallet`, `postgres`, PostgreSQL 18.6 | P3_01 |
| Isolation level | `read committed` (current and default) | P3_01 |
| Row counts | 5,002 customers, 5,003 wallets, 105,001 transactions, 210,000 ledger entries | P3_02 |
| SYSTEM_CLEARING wallet | id 6, `0000000000`, ACTIVE, balance −1,019,314,617.14 | P3_03 |
| Existing P3 records | none | P3_04 |
| User-defined functions in `public` | none | P3_05 |
| Non-internal triggers | result not available (P3_06 was not captured) | — |
| Balance/ledger mismatches | none | P3_07 |

The reconciliation check treats a CREDIT as money in and a DEBIT as money out,
and includes wallets with no ledger entries. Zero mismatches (P3_07) meant any
later mismatch could only come from Portfolio 3.

Evidence:
[P3_01](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_01_Environment.png) ·
[P3_02](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_02_BaselineCounts.png) ·
[P3_03](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_03_ClearingWallet.png) ·
[P3_04](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_04_NoExistingP3Records.png) ·
[P3_05](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_05_NoExistingRoutines.png) ·
[P3_07](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_07_BaselineReconciliation.png)

### 1.2 Dedicated test wallets

[Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_02_Setup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_02_Setup.sql) ran once as a single transaction. It
created three fictional VERIFIED customers and their ACTIVE NGN wallets, then
funded `P3W0000001` with NGN 10,000.00 from the SYSTEM_CLEARING wallet as
deposit `P3-DEP-001`, with one DEBIT and one CREDIT. Validation checks ran
before `COMMIT`.

The recorded result (P3_08) is P3W0000001 = 10,000.00 with one ledger entry,
and P3W0000002 and P3W0000003 = 0.00 with none. All three wallets reconcile.
Using separate `P3...` records kept the Portfolio 2 benchmark wallets and
transactions unchanged.

Evidence:
[P3_08](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_08_SetupWallets.png)

---

## 2. Demonstration 1 — Atomic successful transfer (commit)

**Script:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_03_SuccessfulTransfer.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_03_SuccessfulTransfer.sql)
**Transfer:** NGN 1,000.00 from P3W0000001 to P3W0000002, reference `P3-TRF-001`

### What was recorded

| Stage | P3W0000001 | P3W0000002 | Evidence |
|---|---|---|---|
| Before | 10,000.00 | 0.00 | P3_09 |
| After commit | 9,000.00 | 1,000.00 | P3_10 |

Ledger entries for `P3-TRF-001` (P3_11):

| Wallet | Entry | Amount | balance_after |
|---|---|---|---|
| P3W0000001 | DEBIT | 1,000.00 | 9,000.00 |
| P3W0000002 | CREDIT | 1,000.00 | 1,000.00 |

### What it shows

The transaction record, both balance updates and both ledger entries were
written inside one transaction and became visible together after `COMMIT`.
The ledger pair balances: one DEBIT and one CREDIT of the same amount. Each
`balance_after` equals the wallet's cached balance after the transfer, so the
two stored derived values (`wallets.balance` and `ledger_entries.balance_after`)
agree.

The script locks both wallets in ascending `wallet_id` order before changing
them. It also checks before `COMMIT` that the balances, the ledger pair and the
reconciliation are correct, raising an exception if they are not.

**Evidence note:** P3_09 is the script's Evidence A query. P3_10 and P3_11 are
ad-hoc queries run after the transfer, not the script's Evidence B–D. The
transfer block's `Messages` output was not captured as a screenshot; the
committed result it produced is shown in P3_10 and P3_11.

Evidence:
[P3_09](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_09_TransferBefore.png) ·
[P3_10](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_10_TransferAfter.png) ·
[P3_11](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_11_TransferLedger.png)

---

## 3. Demonstration 2 — Rollback after a deliberate failure

**Script:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_04_Rollback.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_04_Rollback.sql), run section by
section in one Query Tool tab
**Attempted transfer:** NGN 1,000.00 from P3W0000001 to P3W0000002, reference
`P3-FAIL-001`

### Sequence recorded

1. **Opening state (P3_12):** P3W0000001 = 9,000.00, P3W0000002 = 1,000.00.
2. **Partial transfer, transaction left open (P3_13):** wallets 5009 and 5010
   were locked in ascending order. `P3-FAIL-001` was inserted as PENDING
   (transaction id 105008), the sender was debited to 8,000.00 and its DEBIT
   entry was written. The recipient was not credited.
3. **Uncommitted state (P3_14):** inside the same session, `P3-FAIL-001`
   appears as PENDING and the sender's balance reads 8,000.00.
4. **Deliberate failure (P3_15):** a second DEBIT for transaction 105008 was
   rejected: `duplicate key value violates unique constraint
   "uq_ledger_entries_txn_entry_type"`, key `(105008, DEBIT)`, SQLSTATE 23505.
5. **ROLLBACK (P3_16):** completed successfully.
6. **After rollback (P3_17, P3_18):** balances are 9,000.00 and 1,000.00 again,
   with 2 and 1 ledger entries and both reconciled. `P3-FAIL-001` has
   0 transaction rows and 0 ledger entries.

### What it shows

This is the case-study scenario: an error occurs after the sender is debited
but before the recipient is credited. The error put the transaction into an
aborted state, and `ROLLBACK` discarded every change made in it: the PENDING
transaction row, the sender's debit and the DEBIT ledger entry. No partial
transfer survived.

The ledger entry counts in P3_17 (2 and 1) match the counts before the attempt,
which confirms that no ledger row was left behind. As the Portfolio 1 design
states, a rolled-back transfer leaves no PENDING or FAILED record. Keeping a
record of failed attempts would need a separate failure-recording policy,
which was not implemented.

The constraint `uq_ledger_entries_txn_entry_type` also acted as a safeguard
here: it rejected a second DEBIT for the same transaction.

Evidence:
[P3_12](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_12_RollbackBefore.png) ·
[P3_13](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_13_RollbackDebitPending.png) ·
[P3_14](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_RollbackUncommitted.png) ·
[P3_15](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_15_RollbackError.png) ·
[P3_16](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_16_RollbackExecuted.png) ·
[P3_17](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_RollbackAfter.png) ·
[P3_18](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_18_RollbackNoRecords.png)

---

## 4. Demonstration 3 — Concurrent spending from one wallet

**Scripts:** [p3_05](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_05_ConcurrencySession1.sql) (Session 1),
[p3_06](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_06_ConcurrencySession2.sql) (Session 2),
[p3_07](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_07_ConcurrencyObserver.sql) (observer).
These files were written after the demonstration and aligned with every
statement visible in the screenshots. Lines that no screenshot shows (the
start of Session 1's posting block and the first lines of the reconciliation
query) are marked `[Reconstructed]`. The screenshots are the authoritative
record of the executed SQL.

### 4.1 Scenario

P3W0000001 held NGN 9,000.00. Two sessions each tried to spend NGN 8,000.00
from it: Session 1 to P3W0000002 (`P3-CONC-001`) and Session 2 to P3W0000003
(`P3-CONC-002`). Only one can succeed without overspending.

Both sessions ran at READ COMMITTED (P3_19, P3_20):

| Session | application_name | PID |
|---|---|---|
| Session 1 | `P3_SESSION_1` | 39364 |
| Session 2 | `P3_SESSION_2` | 41144 |

### 4.2 Recorded sequence

The locking test was run twice. In the first attempt, leftover pasted text
caused a syntax error in Session 1. The error aborted Session 1's transaction
and released its locks, so both sessions were rolled back and the test was
repeated successfully. By their clock times, P3_22 and P3_23 were captured
during the first attempt and P3_24–P3_28 during the repeat. The table follows
the steps of the successful attempt. Because the screenshots come from two
attempts, no single lock-wait duration is reported.

| Step | Session | Action and result | Evidence |
|---|---|---|---|
| 1 | Session 2 | Opening balances 9,000.00 / 1,000.00 / 0.00 | P3_21 |
| 2 | Session 1 | `BEGIN ISOLATION LEVEL READ COMMITTED`; locked wallets 5009 and 5010 with `FOR UPDATE` (9,000.00 and 1,000.00) | P3_22 |
| 3 | Session 2 | `BEGIN ISOLATION LEVEL READ COMMITTED`; `FOR UPDATE` on P3W0000001 and P3W0000003; the query waits | P3_23 |
| 4 | Session 1 | Blocking query: Session 1 active, no wait event, `blocked_by` {}; Session 2 active, `wait_event_type` Lock, `blocked_by` {39364} | P3_24 |
| 5 | Session 1 | One `DO` block validated the wallets and funds and posted `P3-CONC-001`. NOTICE: `posted but NOT committed. Sender: 1000.00, recipient: 9000.00` | P3_25 |
| 6 | Observer | Before commit: 9,000.00 / 1,000.00, `visible_transfer_count` 0 | P3_26 |
| 7 | Session 1 | `COMMIT` | — |
| 8 | Session 2 | The waiting query returns: P3W0000001 = 1,000.00, P3W0000003 = 0.00 | P3_27 |
| 9 | Session 2 | Validation-only block: `Transfer P3-CONC-002 rejected: insufficient funds. Available: 1000.00, required: 8000.00` (SQLSTATE P0001), then `ROLLBACK` | P3_28 |
| 10 | Observer | After commit: 1,000.00 / 9,000.00, `visible_transfer_count` 1 | P3_29 |
| 11 | Observer | Reconciliation: 1,000.00 / 9,000.00 / 0.00, ledger entries 3 / 2 / 0, all reconciled | P3_30 |

Session 1's `COMMIT` (step 7) and Session 2's `ROLLBACK` (step 9) were
executed, but their own messages were not captured as screenshots. The
effect of the `COMMIT` is shown in P3_27 and P3_29. Later outputs are
consistent with the `ROLLBACK`: P3W0000003 still has no ledger entries
(P3_30) and no `P3-CONC-002` transaction exists (P3_32).

### 4.3 READ COMMITTED visibility

While Session 1's transaction was open, Session 1 itself saw the new balances
(the NOTICE in P3_25: 1,000.00 / 9,000.00). The observer still saw
9,000.00 / 1,000.00 and could not see `P3-CONC-001` at all (P3_26). After
`COMMIT`, the observer saw the new balances and the transfer (P3_29).

This shows that READ COMMITTED does not allow dirty reads: other sessions
only see changes once they are committed. It does not on its own prevent
overspending, because a session that only reads the balance could still read
9,000.00 before Session 1 commits and approve a second transfer. That unsafe
case was explained but not run as a demonstration.

### 4.4 Row locking

`SELECT ... FOR UPDATE` in Session 1 placed row locks on wallets 5009 and
5010. When Session 2 asked for a lock on wallet 5009 it had to wait
(P3_23). `pg_stat_activity` and `pg_blocking_pids()` confirmed the cause
(P3_24): Session 2 (41144) was waiting on a `Lock` and was blocked by
Session 1 (39364).

Session 1 shows as `active` with no wait event because it was the session
running the blocking query. Seen from an independent session, a session that
holds an open transaction between statements would normally appear as
`idle in transaction`.

Both sessions requested their locks in ascending `wallet_id` order, as
proposed in Portfolio 1. Wallet 5009 was the first lock in both cases, so
Session 2 waited before taking any other wallet lock.

### 4.5 Insufficient-funds validation after the wait

When Session 1 committed, Session 2's waiting `FOR UPDATE` query completed and
returned P3W0000001 = **1,000.00**, not the 9,000.00 it held when Session 2
started waiting (P3_27). Under READ COMMITTED, a `FOR UPDATE` query that
waited for another transaction uses the newest committed version of the
locked row.

Session 2's validation block then compared that balance with the required
8,000.00 and raised an insufficient-funds exception (P3_28). Session 2 was a
**validation-only attempt**: it did not insert a `P3-CONC-002` transaction,
write ledger entries or execute a second posting routine. It ended with
`ROLLBACK`.

The result matches the case-study business rule: with a balance of 9,000.00
and two competing 8,000.00 transfers, only one succeeded, and the wallet was
not overdrawn.

### 4.6 Reconciliation after the concurrency test

| Wallet | Cached balance | Ledger total | Entries | Reconciled |
|---|---|---|---|---|
| P3W0000001 | 1,000.00 | 1,000.00 | 3 | true |
| P3W0000002 | 9,000.00 | 9,000.00 | 2 | true |
| P3W0000003 | 0.00 | 0.00 | 0 | true |

P3W0000001's three entries are the setup CREDIT, the `P3-TRF-001` DEBIT and the
`P3-CONC-001` DEBIT. P3W0000002's two entries are the `P3-TRF-001` CREDIT and
the `P3-CONC-001` CREDIT. P3W0000003 has none, which confirms that Session 2
moved no money.

Evidence:
[P3_19](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_19_Session1.png) ·
[P3_20](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_20_Session2.png) ·
[P3_21](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_21_ConcurrencyBefore.png) ·
[P3_22](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_22_Session1Locks.png) ·
[P3_23](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_23_Session2Waiting.png) ·
[P3_24](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_24_LockEvidence.png) ·
[P3_25](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_25_TransferUncommitted.png) ·
[P3_26](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_26_ObserverBeforeCommit.png) ·
[P3_27](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_27_Session2AfterWait.png) ·
[P3_28](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_28_InsufficientFunds.png) ·
[P3_29](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_29_ObserverAfterCommit.png) ·
[P3_30](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_30_ConcurrencyReconciliation.png)

---

## 5. Demonstration 4 — Duplicate-reference rejection

**Script:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_08_DuplicateReference.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_08_DuplicateReference.sql)

### What was recorded

Inside a transaction, a new row was inserted by copying the committed
`P3-CONC-001` row (reference, type, both wallet IDs and amount) with status
PENDING. PostgreSQL rejected it (P3_31):

```
ERROR:  duplicate key value violates unique constraint "uq_transactions_reference"
Key (reference)=(P3-CONC-001) already exists.
SQL state: 23505
```

The transaction was then rolled back; that `ROLLBACK` message was not
captured as a screenshot. The verification query (P3_32) returned one row only:
`P3-CONC-001`, 8,000.00, SUCCESSFUL, 2 ledger entries. `P3-CONC-002` did not
appear because no transaction was ever saved under that reference.

### What it shows

The `UNIQUE (reference)` constraint gives **duplicate-request protection** at
the storage layer. A repeated request that reuses a reference cannot create a
second transaction row, so it cannot lead to a second posting for that
reference.

On its own, this is not a complete idempotent retry workflow: in this test
the duplicate simply caused an error and the transaction was rolled back.
The Portfolio 1 design also proposes detecting the duplicate without aborting
the transaction (`ON CONFLICT (reference) DO NOTHING`), comparing the retried
request with the stored row, and returning the original result.

Demonstration 4 did none of that. Those steps were added later, in the
transfer function `public.korapay_transfer_funds` (p3_09, Section 6.1). How
much of it was tested:

| Function behaviour | Test | Evidence |
|---|---|---|
| Identical retry in the same transaction returns the original ID | p3_10 | Recorded: P3_34, P3_35 |
| Identical retry after the first call committed returns the original ID | p3_11 | Not shown: no screenshot or saved output |
| Two identical calls at the same time post only once | p3_19 | Not shown: no screenshot or saved output (Section 12.2) |
| Reusing a reference for a *different* request is rejected | — | Not tested: no script exercises this branch |

Evidence:
[P3_31](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_31_DuplicateReferenceRejected.png) ·
[P3_32](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_32_FinalTransferVerification.png)

---

## 6. Reusable transfer function and retry tests (p3_09–p3_12)

These scripts were run with psql in the IDE terminal; the screenshots show
the terminal output.

### 6.1 Transfer function (p3_09)

[p3_09](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_09_TransferFunction.sql)
creates `public.korapay_transfer_funds(sender wallet number, recipient wallet
number, amount, reference) RETURNS BIGINT`. It validates its arguments, claims
the reference with `INSERT … ON CONFLICT ON CONSTRAINT
uq_transactions_reference DO NOTHING`, returns the original `transaction_id`
for an identical SUCCESSFUL retry and rejects any other reuse of the
reference. It then locks both wallets in ascending `wallet_id` order
(`FOR NO KEY UPDATE`), validates them, and posts the balance updates, the
DEBIT/CREDIT pair and the SUCCESSFUL status. It neither catches errors nor
commits.

**Recorded (P3_33):** `CREATE FUNCTION`, `COMMENT`, and the catalogue row
`korapay_transfer_funds(character varying, character varying, numeric,
character varying)`, returning `bigint`, language `plpgsql`,
`security_definer` = `f`, settings `search_path=pg_catalog, public`. The
screenshot does not show the function body.

### 6.2 Same-transaction retry (p3_10)

[p3_10](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_10_FunctionRetryTest.sql)
called the function twice with identical arguments (`P3-FUNC-RETRY-001`,
1.00) inside one transaction, then rolled back.

**Recorded (P3_34):** "First call returned: 105011", "Second call returned:
105011", `ids_match` = `t`.
**Recorded (P3_35):** after ROLLBACK, 0 transaction rows, 0 ledger rows via
the reference and 0 ledger rows for the returned ID, followed by the NOTICE
"PASS: balances restored; 0 transaction and 0 ledger rows for
P3-FUNC-RETRY-001".

**What it shows.** Within one transaction the retry returned the original ID
instead of posting again, and the rollback removed the test completely. This
is not a concurrent or post-commit retry.

### 6.3 Post-commit retry (p3_11)

[p3_11](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_11_PostCommitRetryTest.sql)
commits a 1.00 transfer (`P3-FUNC-COMMIT-001`) and then retries it in a new
transaction. **No screenshot or saved output of this run exists**, so its
result is not reported. The P3W balances and ledger entry counts shown in
P3_39 (below) are consistent with one committed 1.00 transfer from p3_11 and
one from p3_12, but they are not direct evidence of the p3_11 retry.

### 6.4 SAVEPOINT recovery (p3_12)

[p3_12](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_12_SavepointDemo.sql)
committed one 1.00 transfer (`P3-SAVE-001`), set a SAVEPOINT, deliberately
attempted an unaffordable transfer (`P3-SAVE-FAIL-001`), rolled back to the
savepoint and committed.

**Recorded (P3_39):** the final reconciliation shows P3W0000001 = 998.00
(ledger 998.00, 5 entries, reconciled) and P3W0000002 = 9,002.00 (ledger
9,002.00, 4 entries, reconciled), followed by the NOTICE "PASS: P3-SAVE-001
committed once with its DEBIT/CREDIT pair; P3-SAVE-FAIL-001 absent; both
wallets reconcile" and "SAVEPOINT demonstration completed: all assertions
passed".

**What it shows.** After the deliberate failure, `ROLLBACK TO SAVEPOINT`
kept the first transfer and discarded only the failed one. The deliberate
insufficient-funds error itself is above the visible part of P3_39 and is
not shown.

Evidence:
[P3_33](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_33_TransferFunctionCreated.png) ·
[P3_34](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_34_FunctionRetrySameID.png) ·
[P3_35](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_35_FunctionRetryRollback.png) ·
[P3_39](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_39_SavepointCommitted.png)

---

## 7. Lab environment (p3_13)

[p3_13](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_13_LabSetup.sql)
ran once as a single transaction. Its saved log
([output/…_P3_13_LabSetup.log](output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_13_LabSetup.log))
records "Stage 1 passed", "Stage 7: all pre-commit assertions passed" and
"P3 lab setup committed". It created:

- 20 fictional lab customers, each with one ledger-backed wallet
  `P3LW000001`–`P3LW000020`, funded with 100,000.00 each by balanced
  deposits `P3L-DEP-001`–`020` from the SYSTEM_CLEARING wallet;
- schema `p3_lab` with `accounts` (20 rows), `transfer_log` and a
  `setup_baseline` snapshot. `p3_lab.accounts` is not linked to the ledger
  and is used for the deliberately unsafe experiments below.

---

## 8. Lost update (p3_14)

**Scripts:** [Session A](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_LostUpdateSessionA.sql),
[Session B](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_14_LostUpdateSessionB.sql)
(pgAdmin, READ COMMITTED, lab account 1 only). Each session stored its
initial read in a session-local temporary table.

**Part 1 — unsafe read-then-write.**
**Recorded (P3_40):** section A3a, `SET balance = (SELECT a_initial_balance
FROM p3_a_initial_read) - 100.00`, returned account 1 = 900.00. The file is
named "SessionB900", but the visible query is Session A's section A3a.
**Recorded (P3_41):** section A4 after both sessions committed: balance
900.00, `expected_correct_balance` 800.00, `amount_lost` 100.00.

**Part 2 — safe relative update.**
**Recorded (P3_42):** lock check while Session B's update waited: PID 6416
active with no wait event and `blocked_by` {}; PID 12104 active,
`wait_event_type` Lock, `blocked_by` {6416}. The application names are
truncated in the screenshot; the query orders by application name, so the
first row is `P3_LOST_UPDATE_A`.
**Recorded (P3_43):** section B5: balance 800.00, `expected_correct_balance`
800.00, `correct` = true, `open_experiment_transactions` 0.

**What it shows.** Writing a value calculated from an earlier read lost one
of two 100.00 withdrawals. A relative `UPDATE … SET balance = balance -
100.00` made the second session wait for the first session's row lock and
then apply its change to the committed value, giving the correct 800.00.

**Not captured as screenshots:** the opening reset (A1), the two stored
initial reads (A2, B1), Session B's unsafe update (B2a), and Session B's
update returning 800.00 after the wait.

Evidence:
[P3_40](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_40_LostUpdateSessionB900.png) ·
[P3_41](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_41_LostUpdateConfirmed.png) ·
[P3_42](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_42_SafeUpdateBlocking.png) ·
[P3_43](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_43_SafeUpdateConfirmed.png)

---

## 9. READ COMMITTED versus REPEATABLE READ (p3_15)

**Script:** [p3_15](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_15_IsolationLevels.sql)
(two pgAdmin sessions, lab account 1).

| Step | Recorded evidence |
|---|---|
| S5 — Session B changes account 1 and commits | `committed_balance` 900.00 (P3_44) |
| S14 — Session A retries in a new REPEATABLE READ transaction | `RETURNING` balance 800.00, `isolation_level` repeatable read (P3_46) |

**What the evidence shows.** The retry in a fresh REPEATABLE READ transaction
applied its update to the committed 900.00 and produced 800.00, so B's change
was not lost.

**Not captured as screenshots:** Session A's READ COMMITTED second read (S6)
and the REPEATABLE READ serialization error (S12, expected SQLSTATE 40001).
P3_44 is named "ReadCommittedSecondRead" but shows Session B's step S5. These
two results are therefore not reported here as observed.

Evidence:
[P3_44](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_44_ReadCommittedSecondRead.png) ·
[P3_46](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_46_RepeatableReadRetry800.png)

---

## 10. Deliberate deadlock (p3_16)

**Script:** [p3_16](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_16_DeadlockDemo.sql).
Session A locked lab account 1 then 2; Session B locked account 2 then 1,
using `SELECT ... FOR UPDATE` only.

**Recorded (P3_47):** Session B (`P3_DEADLOCK_B`) received
`ERROR: deadlock detected`, SQL state **40P01**, with the detail "Process 34628
waits for ShareLock on transaction 816; blocked by process 3028. Process 3028
waits for ShareLock on transaction 817; blocked by process 34628", while
locking a tuple in relation `accounts`. Session B was therefore the victim.

**Recorded (P3_48):** afterwards, account 1 = 800.00 and account 2 = 1,000.00,
with `updated_at` values from before the deadlock demonstration, and
`open_experiment_transactions` = 0.

**What it shows.** PostgreSQL detected the cycle, aborted one transaction and
let the other finish. Because only row locks were taken, the balances were not
changed. The opening values (D3) were not captured as a screenshot; the
earlier `updated_at` values indicate that neither row was modified.

Evidence:
[P3_47](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_47_DeadlockDetected.png) ·
[P3_48](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_48_DeadlockBalancesUnchanged.png)

---

## 11. Unordered versus ordered locking under load (p3_17)

**Scripts:** [setup and check](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_BenchmarkSetup.sql),
[unordered workload](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_UnorderedWorkload.sql),
[ordered workload](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_OrderedWorkload.sql).
Two lab functions differ only in lock order (source then destination, or
lower `account_id` then higher). Each pgbench run used 10 clients, 4 threads,
200 transactions per client, one transfer of 1.00 per transaction and
`--max-tries=1` (no retries).

Recorded pgbench output (pgbench 18.6):

| Measure | Unordered | Ordered |
|---|---|---|
| Transactions processed | 1979 / 2000 | 2000 / 2000 |
| Failed transactions | 21 (1.050%) | 0 (0.000%) |
| Deadlock failures | 21 (1.050%) | 0 (0.000%) |
| Serialization failures | 0 | 0 |
| Average latency | 94.045 ms (including failures) | 1.144 ms |
| Initial connection time | 305.991 ms | 167.733 ms |
| TPS (without initial connection time) | 105.216131 | 8743.551631 |

Recorded integrity check after both runs (P3_49): `negative_balances` 0,
`min_balance` 816.00, `max_balance` 100046.00, `unordered_log_rows` 1979
(`unordered_log_amount` 1979.00), `ordered_log_rows` 2000
(`ordered_log_amount` 2000.00), `other_log_rows` 0.

**What it shows.** Unordered locking produced 21 deadlocks; ordered locking
produced none in the same workload. Each variant's log count equals its
number of processed transactions, so failed transactions left no log rows and
no partial transfers.

**Interpretation limits.** Each variant was run once. A deadlock is only
detected after `deadlock_timeout` (1 s by default), which inflates the
unordered latency and lowers its TPS; the throughput figures are not a general
performance comparison. The `total_balance` and `total_matches_baseline`
columns are outside the visible area of P3_49, and no "before" check was saved,
so conservation of the lab total is not claimed from this evidence.

Evidence:
[unordered output](output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_PgbenchUnordered.txt) ·
[ordered output](output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_17_PgbenchOrdered.txt) ·
[P3_49](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_49_PgbenchIntegrityConfirmed.png)

---

## 12. Lock timeout, concurrent retries and final checks (p3_18–p3_20)

### 12.1 Lock timeout (p3_18) — additional experiment

**Script:** [p3_18](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_18_LockTimeout.sql).
Session A held a `FOR UPDATE` lock on lab account 3. Session B ran
`SET LOCAL lock_timeout = '3s'` and requested the same row.

**Recorded (P3_50):** Session B received `ERROR: canceling statement due to
lock timeout`, SQL state **55P03**, while locking a tuple in relation
`accounts`; the query completed after 00:00:03.094.

**Recorded (P3_51):** afterwards account 3 = 100,016.00 with `updated_at`
2026-10-23 16:29:41 (earlier than the experiment), `lock_timeout_now` = 0 and
`open_experiment_transactions` = 0.

**What it shows.** With a lock timeout, a blocked request fails after a fixed
time instead of waiting indefinitely; the caller can roll back and retry or
report the failure. `SET LOCAL` applied only inside B's transaction, and no
data changed.

Evidence:
[P3_50](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_50_LockTimeout.png) ·
[P3_51](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_51_LockTimeoutVerified.png)

### 12.2 Concurrent identical retries (p3_19)

**Script:** [p3_19](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_19_ConcurrentRetry.sql).
Two sessions called `public.korapay_transfer_funds` with identical arguments
(`P3LW000001` → `P3LW000002`, 1.00): in part 1 the first caller committed, in
part 2 the first caller rolled back.

**Evidence status: none saved.** The script exists, and a result was
reported for it, but no saved screenshot or output file contains that result.
No transaction IDs or other figures are given here for this reason.

- `P3_53_ConcurrentRetryVerified.png` was meant to show the final
  verification (R13), but it is a
  byte-for-byte copy of `P3_54_FinalIntegrityChecks.png`. Being identical does
  not mean it proves the same result: it shows the p3_20 integrity checks, not
  the p3_19 verification.
- P3_53 is also untracked in Git, so it is not in the submitted repository.
- There are no screenshots of Session B waiting (R6) or of either session's
  returned IDs.
- Check 11 of p3_20 (the two p3_19 references) is below the visible rows of
  P3_54.

**What it would show, if confirmed.** Each reference would have exactly one
SUCCESSFUL transfer with one ledger pair, meaning the identical concurrent
request did not post twice. This is the expected behaviour of the function
(Section 6.1), but this portfolio has no evidence that it was observed.

### 12.3 Final integrity checks (p3_20)

**Script:** [p3_20](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_20_FinalIntegrityChecks.sql),
one read-only query with 12 checks.

**Recorded (P3_54):** the result has 12 rows; checks 1–5 are visible and all
show `pass = true` (wallet reconciliation, no negative customer balances,
correct DEBIT/CREDIT pairs, no ledger entries on PENDING/FAILED transactions,
no duplicate references). Rows 6–12, including check 11 (the two p3_19
references), are below the visible area, so their results are not shown.
The claim that all 12 passed is not confirmed by saved evidence.

Evidence:
[P3_54](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_54_FinalIntegrityChecks.png)

---

## 13. Overall conclusions

| Property | Demonstration | Result |
|---|---|---|
| Atomic commit | 1 | Both balance updates, the transaction row and the ledger pair committed together |
| Atomic rollback | 2 | A failure after the debit left no transaction row, debit or ledger entry |
| No dirty reads (READ COMMITTED) | 3 | The observer could not see Session 1's uncommitted transfer |
| Overspending prevented by row locks | 3 | Session 2 waited, then saw the committed 1,000.00 and was rejected |
| Ledger consistency | 1–3 | Every P3 wallet's cached balance matched its ledger total |
| Duplicate-request protection | 4 | A second row with an existing reference was rejected |
| Idempotent retry in one transaction | p3_10 | Both calls returned 105011; ROLLBACK left no rows |
| Partial rollback with SAVEPOINT | p3_12 | The first transfer was kept, the failed one discarded; both wallets reconcile |
| Lost update and its prevention | p3_14 | Unsafe absolute write left 900.00 (100.00 lost); relative update waited and gave 800.00 |
| Retry after concurrent change (REPEATABLE READ) | p3_15 | A fresh transaction applied its update to the committed value (800.00) |
| Deadlock detection | p3_16 | One session was aborted with 40P01; balances unchanged |
| Consistent lock order | p3_17 | 21 deadlock failures unordered, 0 ordered, in the same workload |
| Bounded lock waits | p3_18 | A blocked request failed with 55P03 after about 3 s; no data changed |
| Concurrent identical retries | p3_19 | Not shown: no saved evidence of the result |
| Final integrity | p3_20 | Checks 1–5 visibly passed; checks 6–12 not shown |

Constraints protect stored values, but they cannot coordinate competing
requests on their own. The demonstrations show the roles together:
transactions make each transfer all-or-nothing, row locks serialise access to
the same wallet, and unique constraints block duplicate references and
duplicate ledger entries.

## 14. Limitations

- **Isolation levels:** READ COMMITTED and REPEATABLE READ were used;
  SERIALIZABLE was not tested. For p3_15, the READ COMMITTED second read (S6)
  and the REPEATABLE READ serialization error (S12) were not captured as
  screenshots.
- **p3_19 evidence:** none saved. P3_53 is an identical, untracked copy of
  P3_54 (the p3_20 result). The script exists, but its reported result has
  no saved evidence, so no figures are given for it.
- **p3_20 evidence:** P3_54 shows checks 1–5 only; checks 6–12 are outside the
  visible area.
- **p3_09–p3_14 evidence:** p3_11 has no screenshot or saved output (there are
  no P3_36–P3_38 files). P3_33 does not show the function body. P3_39 does not
  show the deliberate SAVEPOINT error. For p3_14, the initial reads, Session
  B's unsafe write and Session B's 800.00 result were not captured, and P3_40
  shows Session A's section A3a despite its "SessionB900" name.
- **Unsafe case on wallets not run:** the overspending that could happen on
  wallets without `FOR UPDATE` was explained, not demonstrated. A lost update
  was demonstrated only on the lab table (p3_14).
- **Session 2 was validation only:** no second transfer was posted, so a
  failed posting attempt by Session 2 was not observed.
- **Idempotency:** in Demonstrations 1–4, unique-reference enforcement is
  duplicate-request protection, not a complete idempotent retry workflow. The
  later `korapay_transfer_funds` function (p3_09) adds retry handling. Only the
  same-transaction retry (p3_10) has saved evidence. The post-commit (p3_11)
  and concurrent (p3_19) retries have none, and rejection of a reused
  reference with different details was never tested (see Section 5).
- **Reconstructed SQL:** `p3_05`–`p3_07` were written after the demonstration
  and aligned with the screenshots. The lines no screenshot shows are marked
  `[Reconstructed]`.
- **Missing trigger check:** P3_06 is unavailable, so no result is reported
  for non-internal triggers. P3_05 covers user-defined functions only.
- **Missing screenshots, not missing steps:** the `P3-TRF-001` transfer
  block's messages, Session 1's `COMMIT`, Session 2's `ROLLBACK` and the
  `ROLLBACK` after the duplicate-reference error were executed, but their own
  messages were not captured. Later outputs show the resulting state
  (P3_10–P3_11, P3_27, P3_29, P3_30, P3_32). P3_10 and P3_11 are ad-hoc
  queries.
- **Two locking attempts:** the concurrency screenshots come from a failed
  first attempt and a successful repeat, so lock-wait times are not compared.
- **Scale:** the manual demonstrations were single runs with two sessions.
  The p3_17 load test ran each variant once on the lab table only; its
  throughput figures are affected by deadlock detection time.
- **Posting routine and permissions:** Demonstrations 1–4 used transaction
  blocks and `DO` blocks. The p3_09 function runs with the caller's
  privileges; the `SECURITY DEFINER` routine and revoked application
  privileges proposed in Portfolio 1 were not implemented.
