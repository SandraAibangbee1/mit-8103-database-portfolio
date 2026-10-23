# MIT 8103: Advanced Database Systems Portfolio

**Student:** Sandra Aibangbee  
**Case Study:** KoraPay Wallet (A Simulated Nigerian Fintech Platform)  
**Project Status:** Portfolios 1–3 implemented: Portfolio 1 schema and constraint tests, Portfolio 2 query optimisation investigations and performance analysis, and Portfolio 3 transaction and concurrency demonstrations. Portfolios 4–5 pending.

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
   - **Scope:** Conceptual and logical data modeling, Entity-Relationship (ER) diagram, relational schema design, primary/foreign keys, integrity constraints (`CHECK`, `UNIQUE`), and database normalisation documentation. See the full [Case Study Specification](./portfolio-1-database-design/case-study.md).

2. [`portfolio-2-query-optimisation/`](./portfolio-2-query-optimisation/):
   - **Status:** Implemented: three query optimisation investigations with execution plans and performance analysis. See the [Portfolio 2 README](./portfolio-2-query-optimisation/README.md).
   - **Scope:** Benchmarking and measuring transaction-history and ledger reconciliation queries before and after indexing strategies and query structure improvements.

3. [`portfolio-3-transactions-concurrency/`](./portfolio-3-transactions-concurrency/):
   - **Status:** Implemented: atomic commit, rollback after a deliberate failure, two concurrent sessions under READ COMMITTED with `SELECT ... FOR UPDATE` row locking and insufficient-funds rejection, ledger reconciliation, and duplicate-reference rejection. See the [Portfolio 3 README](./portfolio-3-transactions-concurrency/README.md) and the [transactions and concurrency analysis](./portfolio-3-transactions-concurrency/transactions-concurrency-analysis.md).
   - **Scope:** Demonstrating transaction commit and rollback, READ COMMITTED visibility, simultaneous transfer locking (`SELECT ... FOR UPDATE`), race-condition mitigation, and duplicate-request protection. Later lab experiments add REPEATABLE READ, a deliberate deadlock and an ordered-versus-unordered pgbench comparison, a lock-timeout experiment, concurrent identical retries of the transfer function and final integrity checks.

4. [`portfolio-4-nosql/`](./portfolio-4-nosql/):
   - **Status:** Planned
   - **Scope:** Implementing transaction notifications as documents in a NoSQL database and documenting architectural trade-offs.

5. [`portfolio-5-distributed-cloud/`](./portfolio-5-distributed-cloud/):
   - **Status:** Planned
   - **Scope:** Proposing a deployment architecture addressing replication, high availability, data consistency, disaster recovery, and the trade-offs of distributing financial data.


