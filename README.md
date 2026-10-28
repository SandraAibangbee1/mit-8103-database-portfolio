# MIT 8103: Advanced Database Systems Portfolio

**Student:** Sandra Aibangbee  
**Case Study:** KoraPay Wallet (A Simulated Nigerian Fintech Platform)  
**Project Status:** All five portfolios implemented: Portfolio 1 schema and constraint tests, Portfolio 2 query optimisation investigations and performance analysis, Portfolio 3 transaction and concurrency demonstrations, Portfolio 4 NoSQL MongoDB notification documents, and Portfolio 5 cloud deployment and distributed-systems analysis.

---

## Project Overview

This repository hosts the practical portfolio submissions for **MIT 8103: Advanced Database Systems**. The central case study is **KoraPay Wallet**, a fictional Nigerian fintech platform providing digital wallets and peer-to-peer money transfers for individuals and small businesses, designed strictly for academic and educational evaluation.

### Planned Core Capabilities
- **Customer & Wallet Management:** Customer registration with one Nigerian naira (NGN) wallet per customer.
- **Fund Movements:** Simulated deposits and withdrawals (utilising a system clearing account for balanced ledger records) and internal wallet-to-wallet transfers.
- **Transaction Safety & Atomicity:** Ensuring the sender's debit and recipient's credit commit together or roll back completely upon failure.
- **Concurrency & Overdraft Prevention:** Preventing overspending when simultaneous transfer requests hit the same wallet.
- **Duplicate Request Protection:** Tracking unique transaction request references to avoid duplicate processing.
- **Auditable Ledger & Reversals:** Recording balanced double-entry ledger entries for completed transactions and linked compensating entries for reversals.
- **Reporting & Notifications:** Generating transaction histories, account statements, reconciliation reports, and recording transaction notifications in a document store.

### Project Scope Boundaries
- **In Scope:** Internal wallet transfers, simulated deposits and withdrawals, transaction histories, balance-to-ledger reconciliation, and transaction notification documents.
- **Out of Scope:** External bank transfers, card processing, airtime, bill payments, loans, and foreign currencies. No real money or external payment gateway integrations will be used.

> [!NOTE]
> All customer identities, accounts, balances, and transaction records used in this project are strictly fictional.

---

## Planned Portfolio Deliverables

The implementation will be carried out across five dedicated portfolio milestones:

1. [`portfolio-1-database-design/`](./portfolio-1-database-design/):
   - **Status:** Implemented: four-table schema created and constraint tests completed. See the [Portfolio 1 README](./portfolio-1-database-design/README.md).
   - **Scope:** Conceptual and logical data modeling, Entity-Relationship (ER) diagram, relational schema design, primary/foreign keys, integrity constraints (`CHECK`, `UNIQUE`), and database normalisation documentation. See the full [Case Study Specification](./portfolio-1-database-design/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_CaseStudy.md).

2. [`portfolio-2-query-optimisation/`](./portfolio-2-query-optimisation/):
   - **Status:** Implemented: three query optimisation investigations with execution plans and performance analysis. See the [Portfolio 2 README](./portfolio-2-query-optimisation/README.md).
   - **Scope:** Measuring three reporting queries (a wallet statement, daily transfer totals and the top sending wallets) before and after two indexes and one query rewrite, using `EXPLAIN (ANALYZE, BUFFERS)` on a synthetic dataset. No reconciliation query was benchmarked.

3. [`portfolio-3-transactions-concurrency/`](./portfolio-3-transactions-concurrency/):
   - **Status:** Implemented: atomic commit, rollback after a deliberate failure, two concurrent sessions under READ COMMITTED with `SELECT ... FOR UPDATE` row locking and insufficient-funds rejection, ledger reconciliation, and duplicate-reference rejection. See the [Portfolio 3 README](./portfolio-3-transactions-concurrency/README.md) and the [transactions and concurrency analysis](./portfolio-3-transactions-concurrency/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P3_TransactionsConcurrencyAnalysis.md).
   - **Scope:** Demonstrating transaction commit and rollback, READ COMMITTED visibility, simultaneous transfer locking (`SELECT ... FOR UPDATE`), race-condition mitigation, and duplicate-request protection. Later experiments add an idempotent transfer function with a same-transaction retry test, a SAVEPOINT test, a lost update, REPEATABLE READ, a deliberate deadlock, an ordered-versus-unordered pgbench comparison, a lock timeout and final integrity checks. A concurrent identical-retry test was also scripted, but no evidence of its result was saved.

4. [`portfolio-4-nosql/`](./portfolio-4-nosql/):
   - **Status:** Implemented interactively on MongoDB Atlas: a collection with JSON Schema validation, create, read, update and delete operations, status aggregation, a unique index with duplicate rejection, and an access-path comparison. The script files were written afterwards and have not been run as files. See the [Portfolio 4 README](./portfolio-4-nosql/README.md) and the [NoSQL analysis](./portfolio-4-nosql/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_NoSQLAnalysis.md).
   - **Scope:** Implementing transaction notifications as documents in a NoSQL database and documenting architectural trade-offs.

5. [`portfolio-5-distributed-cloud/`](./portfolio-5-distributed-cloud/):
   - **Status:** Implemented: MongoDB Atlas cluster observed on AWS eu-west-3 (3-node replica set confirmed with `db.hello()`, data read from the cloud), and a separate local PostgreSQL 18 primary–standby experiment in Docker (asynchronous streaming replication, a test row read on the replica). Failover, recovery and sharding were discussed but not tested. See the [Portfolio 5 README](./portfolio-5-distributed-cloud/README.md) and the [distributed/cloud analysis](./portfolio-5-distributed-cloud/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_DistributedCloudAnalysis.md).
   - **Scope:** Observing a cloud-hosted MongoDB deployment, testing local PostgreSQL replication, and analysing replication, availability, consistency, disaster recovery and the trade-offs of distributing financial data.


