# Portfolio 2 — Performance Analysis (Draft)

- **Course:** MIT 8103 Advanced Database Systems
- **Student:** Sandra Aibangbee (2026/A/MIT/0301/301897710)
- **Database:** `korapay_wallet` (PostgreSQL 18), loaded with the synthetic P2 benchmark dataset
- **Dataset:** 5,000 new customer wallets (5,003 wallets in total, including the existing Portfolio 1 wallets) and 210,000 ledger entries

> **Status: analysis draft for review.** This document currently covers Q01 only.
> Other queries and the overall conclusions have not been written yet.

---

## Q01 — Wallet statement (latest 50 ledger entries)

### 1. Purpose

Q01 returns the 50 newest ledger entries for wallet `P2W0000001`. It joins
`wallets`, `ledger_entries` and `transactions`, and orders by
`ledger_entries.created_at DESC, ledger_entry_id DESC`.

This is the query behind a customer mini-statement or a "recent transactions"
screen. It is intended to be a frequent application query, so it should respond
quickly. This frequency is a design assumption; the actual workload frequency
has not been measured.

| Item | File |
|---|---|
| Query | [queries/q01_wallet_statement.sql](queries/q01_wallet_statement.sql) |
| EXPLAIN script | [sql/q01_explain.sql](sql/q01_explain.sql) |
| Index script | [sql/q01_create_index.sql](sql/q01_create_index.sql) |
| Plan before index | [plans/q01_before.txt](plans/q01_before.txt) |
| Plan after index | [plans/q01_after.txt](plans/q01_after.txt) |

Plans were captured with `EXPLAIN (ANALYZE, BUFFERS)`.

### 2. Recorded results

| Measure | Before index | After index |
|---|---:|---:|
| Execution Time (PostgreSQL) | 133.082 ms | 0.965 ms |
| Shared buffer hits (top node) | 2,670 | 603 |
| Rows returned | 50 | 50 |
| Matching ledger entries for the wallet | 149 | 149 |

- **Recorded speed-up:** 133.082 ÷ 0.965 ≈ **137.91 times** faster.
- **Buffer reduction:** 2,670 → 603 shared hits, which is 2,067 fewer (about 77% fewer).
- **Index size:** `idx_p2_ledger_wallet_recent` has a measured disk size of **8,344 kB**.

The times above are PostgreSQL's `Execution Time` lines from the plans, not
pgAdmin's total query runtime, which also includes client and network overhead.

### 3. Before the index: what the plan shows

- **Plan:** [plans/q01_before.txt](plans/q01_before.txt)
- **Screenshots:** [P2_05 Before plan (top)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_05_Q01_BeforePlan_Top.png), [P2_06 Before plan (bottom)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_06_Q01_BeforePlan_Bottom.png)

What the plan does:

- `wallets` is found quickly through the existing unique index
  `uq_wallets_wallet_number` (1 row, 3 buffers).
- `ledger_entries` had no index on `wallet_id`, so PostgreSQL ran a
  **Parallel Seq Scan** using one worker plus the leader
  (`rows=105000.00 loops=2`). Together they read **all 210,000 ledger entries**
  (2,205 buffers) to find the 149 that belong to this wallet.
- A **Hash Join** kept the 149 matching entries. Each one then needed an
  **Index Scan on `pk_transactions`**, giving 149 lookups and 447 buffers.
- A **Sort** (top-N heapsort) ordered the rows, and **Gather Merge** combined the
  results from the two processes before the **Limit** returned 50 rows.

**Observation to review:** the Sort node reports about 8.4 ms per process, but
the Gather Merge node finishes at about 129–133 ms. Much of the recorded
before-time therefore appears at the parallel gather step, not in reading the
table. Parallel-worker start-up and coordination may have added to this single
run, but the plan alone cannot show exactly how much time they contributed.

### 4. Index created

- **Script:** [sql/q01_create_index.sql](sql/q01_create_index.sql)
- **Screenshot:** [P2_07 Index](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_07_Q01_Index.png)

```sql
CREATE INDEX idx_p2_ledger_wallet_recent
ON ledger_entries (
    wallet_id,
    created_at DESC,
    ledger_entry_id DESC
);
```

**Why this column order:**

1. **`wallet_id` first.** The query filters on one wallet with an equality
   condition. Putting it first groups each wallet's entries together in the
   index, so PostgreSQL can jump straight to them instead of scanning the
   whole ledger.
2. **`created_at DESC`, then `ledger_entry_id DESC`.** These match the
   `ORDER BY` exactly, including direction and the tie-breaker. In principle,
   this lets an ordered index scan return a wallet's entries newest-first
   without a separate sort.
3. **Alternative order.** Leading with `wallet_id` suits this equality filter.
   An index starting with `created_at` may support chronological retrieval,
   but can require scanning entries for other wallets.

### 5. After the index: what the plan shows

- **Plan:** [plans/q01_after.txt](plans/q01_after.txt)
- **Screenshots:** [P2_08 After plan (top)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_08_Q01_AfterPlan_Top.png), [P2_09 After plan (bottom)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_09_Q01_AfterPlan_Bottom.png)

What the plan does:

- The parallel sequential scan is gone. PostgreSQL now uses a
  **Bitmap Index Scan on `idx_p2_ledger_wallet_recent`**
  (`Index Cond: wallet_id = w.wallet_id`, 4 buffers). It follows this with a
  **Bitmap Heap Scan on `ledger_entries`**, which retrieves exactly the
  **149 matching entries** (149 heap blocks, 153 buffers).
- The plan no longer runs in parallel (no Gather/Gather Merge node).
- The `pk_transactions` lookups are unchanged: 149 lookups, 447 buffers. They
  are now the largest share of the 603 buffers.
- **A Sort node is still present** (top-N heapsort over 149 rows), and the
  **Limit** still returns 50 rows.

**What the index did *not* do in this recorded plan:**

- It did **not** remove the sort. A bitmap scan reads matching rows in
  physical table order, not index order. The planner therefore still sorted
  the rows on `created_at DESC, ledger_entry_id DESC`. Only the leading
  `wallet_id` column appears in the `Index Cond`.
- It did **not** stop reading after 50 entries. All 149 of the wallet's
  entries were fetched and joined before the sort and limit.

**What explains the improvement:** two changes happened together.

1. **Reduced scanning:** PostgreSQL read 149 targeted rows instead of all
   210,000 rows.
2. **Parallel to serial:** the plan changed from a parallel plan (one worker
   plus the leader, combined by Gather Merge) to a serial plan.

The plans cannot separate how much of the time saving came from each change.
In particular, they cannot establish exactly how much time parallel-worker
overhead added to the before run. The improvement did not come from avoiding
the sort.

**Points to investigate:**

- The planner estimated 42 matching rows but found 149. It is not yet
  confirmed why it chose a bitmap scan instead of an ordered index scan that
  could skip the sort.
- `Heap Blocks: exact=149` means each of the wallet's entries sat on a
  different table page. This matches how the synthetic data was loaded in
  chronological order across all wallets.

### 6. Trade-offs of the index

- **Storage:** the index has a measured disk size of **8,344 kB**, and it will
  grow as the ledger grows. Its pages may occupy shared-buffer cache when they
  are accessed. This is not a fixed allocation of 8,344 kB of shared-buffer
  memory.
- **Write maintenance (expected, not measured):** every new ledger entry must
  also be inserted into this index. Each transaction posts two ledger entries,
  so each transaction updates the index twice. This is expected to add work and
  WAL volume to the write path. New entries go to many different `wallet_id`
  positions in the index, not only to its end.
  - The index was created **after** the benchmark data load, so the load itself
    did not maintain it.
  - Its effect on insert performance **has not yet been measured**.
- **Update and delete churn:** `ledger_entries` is designed to be append-only,
  which would mean little update or delete churn on the index. However, the
  append-only permissions described in Portfolio 1 remain **proposed**; they
  have not been implemented.
- **Benefit:** the index supports an intended frequent, customer-facing read
  pattern (wallet history, newest first). For this query, the extra write cost
  is likely to be worth it, but that judgement should be checked against
  measured insert performance and the system's overall write volume.

### 7. Limitations of these measurements

- These are **individual recorded runs**. They are not an average of repeated
  runs, and they do not guarantee production performance.
- All buffer accesses were **shared hits** (data already in memory). Cold-cache
  timings, with disk reads, could differ.
- The before plan used a **parallel worker** and the after plan did not.
  Worker start-up and coordination overhead, plus normal run-to-run timing
  variation, may affect the comparison.
- The dataset is **synthetic**: 5,000 new customer wallets (5,003 wallets in
  total) and 210,000 ledger entries. Real data volumes and distributions would
  change the absolute numbers.
- Query frequency is an application design assumption, not a measured workload.
- Repeating each query several times and reporting a median would make the
  comparison stronger.

### 8. Related screenshots

- [P2_04 Q01 results](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_04_Q01_Results.png)
- [P2_05 Before plan (top)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_05_Q01_BeforePlan_Top.png)
- [P2_06 Before plan (bottom)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_06_Q01_BeforePlan_Bottom.png)
- [P2_07 Index created](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_07_Q01_Index.png)
- [P2_08 After plan (top)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_08_Q01_AfterPlan_Top.png)
- [P2_09 After plan (bottom)](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_09_Q01_AfterPlan_Bottom.png)
