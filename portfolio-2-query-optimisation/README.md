# Portfolio Milestone 2: Query Optimisation

- **Student:** Sandra Aibangbee
- **Student ID:** 2026/A/MIT/0301/301897710
- **Course:** MIT 8103 Advanced Database Systems
- **Case study:** KoraPay Wallet (simulated Nigerian digital wallet platform)

---

## 1. Purpose

This portfolio measures how three KoraPay Wallet reporting queries perform on a
larger synthetic dataset, and how indexing and query rewriting change their
execution plans. Each investigation records a PostgreSQL execution plan before
and after a change, using `EXPLAIN (ANALYZE, BUFFERS)`, and the results are
analysed in [performance-analysis.md](performance-analysis.md).

All customers, wallets and transactions are fictional. The P2 dataset is
synthetic benchmark data, not the output of a production posting system.

## 2. Database prerequisites

- **PostgreSQL** (plans were recorded on PostgreSQL 18) with **pgAdmin 4**.
- The **`korapay_wallet`** database and its four tables (`customers`, `wallets`,
  `transactions`, `ledger_entries`) created by Portfolio 1:
  - [CreateDatabase.sql](../portfolio-1-database-design/Aibangbee_Sandra_2026_A_MIT_0301_301897710_CreateDatabase.sql)
  - [02_CreateTables.sql](../portfolio-1-database-design/Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql)
- The Portfolio 1 rows (2 customers, 3 wallets including the single
  SYSTEM_CLEARING wallet, and 1 PENDING transaction), from
  [03_ConstraintTests.sql](../portfolio-1-database-design/Aibangbee_Sandra_2026_A_MIT_0301_301897710_03_ConstraintTests.sql).
  The data generation script needs the SYSTEM_CLEARING wallet to exist.
- The P2 synthetic dataset loaded once by the data generation script. After
  loading, the database held 5,003 wallets, 105,001 transactions and 210,000
  ledger entries.

## 3. Folder guide

| Folder / file | Contents |
|---|---|
| [queries/](queries/) | The queries being investigated |
| [sql/](sql/) | Data generation, `EXPLAIN` and index scripts |
| [plans/](plans/) | Saved text output of each `EXPLAIN (ANALYZE, BUFFERS)` run |
| [screenshots/](screenshots/) | pgAdmin evidence of data loading, results, plans and indexes |
| [performance-analysis.md](performance-analysis.md) | Analysis of Q01–Q03 and overall conclusions |

## 4. Summary of the investigations

| Query | Question answered | Change made | Execution Time (before → after) | Shared buffer hits (before → after) |
|---|---|---|---:|---:|
| Q01 | Latest 50 ledger entries for wallet `P2W0000001` | Composite index on `ledger_entries (wallet_id, created_at DESC, ledger_entry_id DESC)` | 133.082 → 0.965 ms | 2,670 → 603 |
| Q02 | Daily successful transfer totals, June 2026 | Partial index on `transactions (created_at)` for SUCCESSFUL TRANSFER rows | 9.657 → 4.249 ms | 1,915 → 173 |
| Q03 | Top 10 sending wallets, June 2026 | Rewrite: aggregate transfers before joining wallets (no new index) | 6.644 → 4.586 ms | 297 → 297 |

These are individual recorded runs, not averages. See
[performance-analysis.md](performance-analysis.md) for the plan details,
trade-offs and limitations.

## 5. Files for each investigation

### Data generation

- [sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_GenerateData.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_GenerateData.sql)
- [screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_01_CheckData.sql](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_01_CheckData.sql) (row-count check query)
- Evidence: [P2_01 Before data expansion](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_01_BeforeDataExpansion.png), [P2_02 After data expansion](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_AfterDataExpansion.png), [P2_03 Data validation](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_03_DataValidation.png)

### Q01 — Wallet statement

| Item | File |
|---|---|
| Query | [queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_wallet_statement.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_wallet_statement.sql) |
| EXPLAIN script | [sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_explain.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_explain.sql) |
| Index script | [sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_create_index.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_create_index.sql) |
| Plans | [plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_before.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_before.txt), [plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_after.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q01_after.txt) |
| Analysis screenshot | [P2_10 Q01 performance analysis](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_10_Q01_PerformanceAnalysis.png) |

### Q02 — Daily transfer totals

| Item | File |
|---|---|
| Query | [queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_daily_transfer_totals.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_daily_transfer_totals.sql) |
| EXPLAIN script | [sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_explain.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_explain.sql) |
| Index script | [sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_create_index.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_create_index.sql) |
| Plans | [plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_before.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_before.txt), [plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_after.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q02_after.txt) |
| Analysis screenshot | [P2_17 Q02 performance analysis](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_17_Q02_PerformanceAnalysis.png) |

### Q03 — Top sending wallets

| Item | File |
|---|---|
| Original query | [queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_top_sending_wallets.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_top_sending_wallets.sql) |
| Rewritten query | [queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_top_sending_wallets_optimised.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_top_sending_wallets_optimised.sql) |
| EXPLAIN scripts | [sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_explain_before.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_explain_before.sql), [sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_explain_after.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_explain_after.sql) |
| Index script | None; Q03 uses the existing Q02 index |
| Plans | [plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_before.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_before.txt), [plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_after.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_q03_after.txt) |
| Analysis screenshot | [P2_24 Q03 performance analysis](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_24_Q03_PerformanceAnalysis.png) |

Plan, result and index screenshots for each query are linked from the
matching section of [performance-analysis.md](performance-analysis.md).

## 6. Running the scripts in pgAdmin

1. In pgAdmin, expand the server and select the **`korapay_wallet`** database
   (not `postgres`).
2. Open **Tools → Query Tool**. Check that the toolbar shows
   `korapay_wallet/postgres@...`.
3. Open a script with the **Open File** button, or paste its contents.
4. Press **F5** (Execute script) to run the whole file.
5. For `EXPLAIN (ANALYZE, BUFFERS)` scripts, the plan appears in the
   **Data Output** tab. Record the `Execution Time` line at the bottom of the
   plan, not pgAdmin's total query runtime shown in the status bar.

Order used in this portfolio, for each query:

1. Run the query file to check the results.
2. Run the `EXPLAIN` script and save the "before" plan.
3. Run the index script (Q01, Q02), or switch to the rewritten query (Q03).
4. Run the `EXPLAIN` script again and save the "after" plan.

`EXPLAIN ANALYZE` executes the query, but these queries only read data.
The index scripts change the schema by adding an index.

## 7. Rerunning: saved plans reflect historical conditions

The saved "before" plans in [plans/](plans/) record the database **as it was
at the time**. Indexes created later are still present, so rerunning a "before"
script now will **not** reproduce the saved "before" plan:

- `idx_p2_ledger_wallet_recent` (Q01) now exists, so Q01 will use it.
- `idx_p2_successful_transfer_date` (Q02) now exists, so Q02 and both Q03
  versions will use it. Both saved Q03 plans already used this index.
- Running an index script a second time fails with an "already exists" error.

Timings will also differ between runs because of caching, other activity on
the machine and normal variation. Treat the saved plans as the recorded
evidence.

## 8. Data generation script: one-time loader

[P2_02_GenerateData.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_GenerateData.sql)
is a **guarded, one-time loader**. It should not be rerun casually.

- It adds 5,000 customers and wallets, 5,000 funding deposits, 100,000
  successful transfers and 210,000 ledger entries, all in one transaction.
- Before changing anything, it checks whether P2 data already exists and stops
  with an error if it does.
- Before committing, it runs integrity checks (counts, balanced entries,
  routing, running balances and balance reconciliation). If any check fails,
  the whole load is rolled back.
- If it stops with an error in pgAdmin, run `ROLLBACK;` before running anything
  else in the same Query Tool tab.
- It is labelled as synthetic benchmark data generation. It is not the
  production posting procedure and does not implement concurrency control.

## 9. AI assistance

ChatGPT and Claude assisted with SQL drafting, explanations and documentation
for this portfolio. I executed the queries in pgAdmin and captured the results
and plans.
