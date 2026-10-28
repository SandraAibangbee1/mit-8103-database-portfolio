# Portfolio 2: Query Optimisation

- **Student:** Sandra Aibangbee
- **Student ID:** 2026/A/MIT/0301/301897710
- **Course:** MIT 8103 Advanced Database Systems
- **Case study:** KoraPay Wallet (simulated Nigerian digital wallet platform)

---

## 1. Purpose

This portfolio measures three KoraPay Wallet reporting queries on a larger synthetic dataset, and how two indexes and one query rewrite change their execution plans. Each query has a PostgreSQL plan recorded before and after the change with `EXPLAIN (ANALYZE, BUFFERS)`. The results are analysed in [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_PerformanceAnalysis.md](Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_PerformanceAnalysis.md).

All customers, wallets and transactions are fictional. The dataset is synthetic benchmark data, not the output of a real posting system.

The case study also mentions measuring reconciliation queries. No reconciliation query was benchmarked in this portfolio.

## 2. What you need first

- **PostgreSQL 18** with **pgAdmin 4** (the server in the screenshots is PostgreSQL 18).
- The **`korapay_wallet`** database and its four tables, created in Portfolio 1:
  - [P1_00_CreateDatabase.sql](../portfolio-1-database-design/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_00_CreateDatabase.sql)
  - [P1_02_CreateTables.sql](../portfolio-1-database-design/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql)
- The Portfolio 1 rows (2 customers, 3 wallets including the SYSTEM_CLEARING wallet, and 1 PENDING transaction) from
  [P1_03_ConstraintTests.sql](../portfolio-1-database-design/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_03_ConstraintTests.sql).
  The data generation script needs the SYSTEM_CLEARING wallet.
- The synthetic dataset, loaded once by the data generation script. Afterwards the database held 5,003 wallets, 105,001 transactions and 210,000 ledger entries (P2_02).

## 3. Folders

All file names start with `Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_`, followed by a number (`01`, `02`, or `Q01`–`Q03` for the three queries) and a short description.

| Folder / file | Contents |
|---|---|
| [queries/](queries/) | The three queries, plus the rewritten Q03 |
| [sql/](sql/) | Row-count check, data generation, `EXPLAIN` and index scripts |
| [plans/](plans/) | Saved text of each `EXPLAIN (ANALYZE, BUFFERS)` plan |
| [screenshots/](screenshots/) | pgAdmin evidence of the data load, results, plans and indexes |
| [P2_PerformanceAnalysis.md](Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_PerformanceAnalysis.md) | Analysis of Q01–Q03 and conclusions |

## 4. Results summary

| Query | Question | Change made | Execution Time (before → after) | Shared buffer hits (before → after) |
|---|---|---|---:|---:|
| Q01 | Latest 50 ledger entries for wallet `P2W0000001` | Composite index on `ledger_entries (wallet_id, created_at DESC, ledger_entry_id DESC)` | 133.082 → 0.965 ms | 2,670 → 603 |
| Q02 | Daily successful transfer totals, June 2026 | Partial index on `transactions (created_at)` for SUCCESSFUL TRANSFER rows | 9.657 → 4.249 ms | 1,915 → 173 |
| Q03 | Top 10 sending wallets, June 2026 | Rewrite: group transfers before joining wallets (no new index) | 6.644 → 4.586 ms | 297 → 297 |

These are single recorded runs, not averages. The figures come from the saved plans in [plans/](plans/).

## 5. What was done, and what was not

**Run and recorded (plans or screenshots saved):**
- the row-count check before loading (P2_01) and the data load with its built-in checks (P2_02, P2_03);
- each query's result (P2_04, P2_11, P2_18, P2_21);
- a before and an after plan for each query (saved in `plans/`; screenshots P2_05–P2_09, P2_12–P2_16, P2_19–P2_23). Two caveats: P2_13 is a duplicate of P2_12, so the bottom of the Q02 "before" plan (9.657 ms) appears only in the saved plan text; and P2_15 is from an earlier Q02 "after" run than the recorded one in P2_16 (see the analysis, Q02 Sections 3 and 5);
- creating both indexes, with their measured sizes (P2_07, P2_14).

**Not done (described or suggested only):**
- measuring the extra write cost of the indexes;
- repeated runs with a median, or cold-cache runs;
- an automated test that Q03's original and rewritten queries return identical results (Section 5 of the analysis explains the reasoning instead);
- benchmarking any reconciliation query.

## 6. Files for each investigation

### Data load

- [sql/…_P2_01_CheckData.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_01_CheckData.sql): row-count check (shown before the load in P2_01).
- [sql/…_P2_02_GenerateData.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_GenerateData.sql): the one-time data loader.
- Evidence: [P2_01 Before data expansion](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_01_BeforeDataExpansion.png), [P2_02 After data expansion](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_AfterDataExpansion.png), [P2_03 Data validation](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_03_DataValidation.png)

### Q01: Wallet statement

| Item | File |
|---|---|
| Query | [queries/…_P2_Q01_WalletStatement.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q01_WalletStatement.sql) |
| EXPLAIN script | [sql/…_P2_Q01_Explain.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q01_Explain.sql) |
| Index script | [sql/…_P2_Q01_CreateIndex.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q01_CreateIndex.sql) |
| Plans | [plans/…_P2_Q01_PlanBefore.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q01_PlanBefore.txt), [plans/…_P2_Q01_PlanAfter.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q01_PlanAfter.txt) |

### Q02: Daily transfer totals

| Item | File |
|---|---|
| Query | [queries/…_P2_Q02_DailyTransferTotals.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_DailyTransferTotals.sql) |
| EXPLAIN script | [sql/…_P2_Q02_Explain.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_Explain.sql) |
| Index script | [sql/…_P2_Q02_CreateIndex.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_CreateIndex.sql) |
| Plans | [plans/…_P2_Q02_PlanBefore.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_PlanBefore.txt), [plans/…_P2_Q02_PlanAfter.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q02_PlanAfter.txt) |

### Q03: Top sending wallets

| Item | File |
|---|---|
| Original query | [queries/…_P2_Q03_TopSendingWallets.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_TopSendingWallets.sql) |
| Rewritten query | [queries/…_P2_Q03_TopSendingWalletsRewrite.sql](queries/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_TopSendingWalletsRewrite.sql) |
| EXPLAIN scripts | [sql/…_P2_Q03_ExplainBefore.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_ExplainBefore.sql), [sql/…_P2_Q03_ExplainAfter.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_ExplainAfter.sql) |
| Index script | None; Q03 uses the existing Q02 index |
| Plans | [plans/…_P2_Q03_PlanBefore.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_PlanBefore.txt), [plans/…_P2_Q03_PlanAfter.txt](plans/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_Q03_PlanAfter.txt) |

Result, plan and index screenshots are linked from each query's section of the analysis.

### Document screenshots

P2_10, P2_17 and P2_24 do not show query output. They show an earlier version of the performance analysis open in the Antigravity IDE while it was being written, with the Claude assistant panel visible in P2_10 and P2_17:
[P2_10](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_10_Q01_PerformanceAnalysis.png) (Q01 section), [P2_17](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_17_Q02_PerformanceAnalysis.png) (Q02 section), [P2_24](screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_24_Q03_PerformanceAnalysis.png) (Q03 section).

Some screenshots also show older file names (for example `q01_wallet_statement.sql`) and older header comments, because they were taken before the files were renamed and tidied.

## 7. Running the scripts in pgAdmin

1. In pgAdmin, select the **`korapay_wallet`** database (not `postgres`).
2. Open **Tools → Query Tool** and check the toolbar shows `korapay_wallet/postgres@...`.
3. Open a script with **Open File**, or paste it in.
4. Press **F5** to run the whole file.
5. For `EXPLAIN (ANALYZE, BUFFERS)` scripts, the plan appears in **Data Output**. Record the `Execution Time` line at the bottom of the plan, not pgAdmin's total runtime in the status bar.

The order used for each query:

1. Run the query file and check the results.
2. Run the `EXPLAIN` script and save the "before" plan.
3. Run the index script (Q01, Q02), or switch to the rewritten query (Q03).
4. Run the `EXPLAIN` script again and save the "after" plan.

`EXPLAIN ANALYZE` really runs the query, but these queries only read data. The index scripts change the schema by adding an index.

## 8. Rerunning: the saved plans are a historical record

The saved "before" plans show the database **as it was then**. The indexes still exist, so rerunning a "before" script now will **not** reproduce the saved plan:

- `idx_p2_ledger_wallet_recent` (Q01) now exists, so Q01 will use it.
- `idx_p2_successful_transfer_date` (Q02) now exists, so Q02 and both Q03 versions will use it. (Both saved Q03 plans already used it.)
- Running an index script again fails with an "already exists" error.

Timings also vary between runs (caching, other activity on the machine). Treat the saved plans as the evidence.

## 9. Data generation script: run once only

[P2_02_GenerateData.sql](sql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P2_02_GenerateData.sql) is a **guarded, one-time loader**.

- It adds 5,000 customers and wallets, 5,000 funding deposits, 100,000 successful transfers and 210,000 ledger entries, all in one transaction.
- It first checks whether P2 data already exists, and stops with an error if it does.
- Before committing, it checks counts, balanced entries, routing, running balances and reconciliation. If any check fails, the whole load is rolled back. The recorded run reported "All checks passed" (P2_03).
- If it stops with an error in pgAdmin, run `ROLLBACK;` before anything else in that Query Tool tab.
- It generates synthetic benchmark data only. It is not the posting procedure and does not implement concurrency control.

## 10. AI assistance

ChatGPT and Claude assisted with SQL drafting, explanations and documentation for this portfolio. I executed the queries in pgAdmin and captured the results and plans.

Claude later simplified the wording of this README, the analysis and the SQL comments, checked the recorded figures against the saved plans and screenshots, and renamed the Portfolio 2 files to the naming standard.
