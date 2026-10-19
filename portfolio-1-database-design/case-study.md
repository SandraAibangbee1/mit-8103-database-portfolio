# Case Study: KoraPay Wallet
## A Simulated Nigerian Fintech Platform

## Organisation / Scenario
KoraPay Wallet is a fictional Nigerian fintech company providing
digital wallets and money transfers to individuals and small businesses.

The platform helps customers send and receive money while maintaining
accurate balances and a clear record of every financial movement.
All customers, identities and transactions used in this project
are fictional.

## Nature of the System
A digital wallet platform where each customer holds one Nigerian
naira (NGN) wallet, makes simulated deposits and withdrawals,
transfers money to other KoraPay wallets and views transaction history.

The database must process money movements accurately, prevent
overspending and protect against duplicate transfer requests.

## Business Problem
Simultaneous requests and repeated submissions can cause incorrect
balances if transactions are not properly controlled.

For example, a customer with ₦10,000 initiates two transfers of
₦8,000 at the same time. Only one transfer should succeed, leaving
₦2,000. The other must be rejected for insufficient funds.

If an error occurs after debiting the sender but before crediting
the recipient, the entire transfer must roll back.

If a customer resubmits the same request because of a connection
problem, the system must recognise it and avoid processing it twice.

## Users of the Database
- Customers: view balances, transfer funds and retrieve statements.
- Customer support officers: investigate failed or disputed transactions.
- Finance and audit officers: reconcile balances and review ledger records.
- Database administrators: maintain access, performance and availability.
- System services: process transactions and generate notifications.

## Major Data Stored
- Customer profiles and simulated verification status.
- Customer wallets, currency, account status and current balances.
- Transactions, including type, amount, status and timestamps.
- Unique request references to prevent duplicate processing.
- Double-entry ledger records for each completed money movement.
- Reversal references linking corrective transactions to originals.
- Notification events and delivery status in a NoSQL database.

## Key Operations Supported
- Register a customer and create a wallet.
- Record simulated deposits and withdrawals.
- Transfer funds between KoraPay wallets.
- Check available funds before approving a transfer.
- Commit all parts of a successful transfer together.
- Roll back incomplete transfers.
- Reject duplicate transaction requests.
- Reverse a completed transaction using linked compensating entries.
- Generate transaction histories and account statements.
- Reconcile wallet balances against ledger entries.
- Record and retrieve transaction notifications.

## Core Business Rules
- Each customer has one NGN wallet.
- Transaction amounts must be greater than zero.
- Customer wallet balances must not become negative.
- A customer cannot transfer money to the same wallet.
- Only active wallets can initiate or receive transfers.
- The sender's debit and recipient's credit must succeed together.
- Each completed money movement must have balanced ledger entries.
- Simulated deposits and withdrawals use a system clearing account
  for the corresponding ledger entries.
- Each transaction request has a unique reference.
- Reversals preserve the original financial records and create
  linked compensating entries.
- Wallet balance updates and ledger entries must be committed
  within the same database transaction.

## Project Scope
The project covers internal wallet transfers, simulated deposits
and withdrawals, transaction histories, reconciliation and notifications.

External bank transfers, card processing, airtime, bill payments,
loans and foreign currencies are outside the scope of this project.
No real money or external payment service will be used.

## Application Across the Five Portfolios
1. Database Design and Modelling:
   Design the ER diagram, relational schema, keys and constraints,
   and explain normalisation.

2. Query Optimisation:
   Measure transaction-history and reconciliation queries before
   and after suitable indexing or query improvements.

3. Transactions and Concurrency:
   Demonstrate commit, rollback, isolation, simultaneous transfers
   and duplicate-request protection.

4. NoSQL:
   Implement transaction notifications as documents and explain
   why a document database suits this data.

5. Distributed and Cloud Databases:
   Propose a deployment approach covering replication, availability,
   consistency, recovery and the trade-offs of distributing
   financial data.

## Evidence and Evaluation
Use actual query outputs, execution plans and screenshots to show
what was implemented and tested. Clearly distinguish proposed
features from completed work and document any limitations.
