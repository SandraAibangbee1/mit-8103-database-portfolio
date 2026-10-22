# Portfolio 3 — Transactions and Concurrency Analysis

- **Student:** Sandra Aibangbee (2026/A/MIT/0301/301897710)
- **Course:** MIT 8103 Advanced Database Systems
- **Environment:** PostgreSQL 18.6, pgAdmin 4, database `korapay_wallet`
- **Isolation level demonstrated:** READ COMMITTED only

This document explains what each recorded demonstration shows. Screenshot
links point to [screenshots/](screenshots/). The scripts and the status of
their SQL text are listed in the [README](README.md#5-scripts-and-their-status).

---

## 1. Starting point

### 1.1 Environment and baseline

The preflight checks ([Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_01_preflight.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_01_preflight.sql))
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

[Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_02_setup.sql) ran once as a single transaction. It
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

**Script:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_03_successful_transfer.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_03_successful_transfer.sql)
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

**Script:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_04_rollback.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_04_rollback.sql), run section by
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

**Scripts:** [p3_05](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_05_concurrency_session1.sql) (Session 1),
[p3_06](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_06_concurrency_session2.sql) (Session 2),
[p3_07](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_07_concurrency_observer.sql) (observer).
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

**Script:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_08_duplicate_reference.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p3_08_duplicate_reference.sql)

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

This is not a complete idempotent retry workflow. The Portfolio 1 design
proposes detecting the duplicate without aborting the transaction (for example
`ON CONFLICT (reference) DO NOTHING`), comparing the retried request's wallets
and amount with the stored row, and returning the original result. None of
that was implemented. In this test the duplicate simply caused an error and
the transaction was rolled back.

Evidence:
[P3_31](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_31_DuplicateReferenceRejected.png) ·
[P3_32](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_32_FinalTransferVerification.png)

---

## 6. Overall conclusions

| Property | Demonstration | Result |
|---|---|---|
| Atomic commit | 1 | Both balance updates, the transaction row and the ledger pair committed together |
| Atomic rollback | 2 | A failure after the debit left no transaction row, debit or ledger entry |
| No dirty reads (READ COMMITTED) | 3 | The observer could not see Session 1's uncommitted transfer |
| Overspending prevented by row locks | 3 | Session 2 waited, then saw the committed 1,000.00 and was rejected |
| Ledger consistency | 1–3 | Every P3 wallet's cached balance matched its ledger total |
| Duplicate-request protection | 4 | A second row with an existing reference was rejected |

Constraints protect stored values, but they cannot coordinate competing
requests on their own. The demonstrations show the roles together:
transactions make each transfer all-or-nothing, row locks serialise access to
the same wallet, and unique constraints block duplicate references and
duplicate ledger entries.

## 7. Limitations

- **Isolation levels:** only READ COMMITTED was demonstrated. REPEATABLE READ
  and SERIALIZABLE were not tested, so no comparison between levels is made.
- **Unsafe case not run:** the overspending that could happen without
  `FOR UPDATE` was explained, not demonstrated.
- **Session 2 was validation only:** no second transfer was posted, so a
  failed posting attempt by Session 2 was not observed.
- **Idempotency:** unique-reference enforcement is duplicate-request
  protection, not a complete idempotent retry workflow.
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
- **Scale:** each demonstration was a single, manually timed run with two
  sessions. Deadlocks and lock contention under load were not tested.
- **Posting routine and permissions:** posting used transaction blocks and
  `DO` blocks. The stored `SECURITY DEFINER` posting procedure and the
  revoked application privileges proposed in Portfolio 1 were not implemented.
