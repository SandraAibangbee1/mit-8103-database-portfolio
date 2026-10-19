# MIT 8103: Advanced Database Systems Portfolio

**Student:** Sandra Aibangbee  
**Case Study:** KoraPay Wallet (A Simulated Nigerian Fintech Platform)  
**Project Status:** Planning Phase (Implementation Not Started)

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
   - **Status:** Planned
   - **Scope:** Conceptual and logical data modeling, Entity-Relationship (ER) diagram, relational schema design, primary/foreign keys, integrity constraints (`CHECK`, `UNIQUE`), and database normalisation documentation. See the full [Case Study Specification](./portfolio-1-database-design/case-study.md).

2. [`portfolio-2-query-optimisation/`](./portfolio-2-query-optimisation/):
   - **Status:** Planned
   - **Scope:** Benchmarking and measuring transaction-history and ledger reconciliation queries before and after indexing strategies and query structure improvements.

3. [`portfolio-3-transactions-concurrency/`](./portfolio-3-transactions-concurrency/):
   - **Status:** Planned
   - **Scope:** Demonstrating transaction commit, rollback, isolation levels, simultaneous transfer locking (`SELECT ... FOR UPDATE`), race-condition mitigation, and idempotency protection against duplicate requests.

4. [`portfolio-4-nosql/`](./portfolio-4-nosql/):
   - **Status:** Planned
   - **Scope:** Implementing transaction notifications as documents in a NoSQL database and documenting architectural trade-offs.

5. [`portfolio-5-distributed-cloud/`](./portfolio-5-distributed-cloud/):
   - **Status:** Planned
   - **Scope:** Proposing a deployment architecture addressing replication, high availability, data consistency, disaster recovery, and the trade-offs of distributing financial data.


