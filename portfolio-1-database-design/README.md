# Portfolio Milestone 1: Database Design and Modelling

**Student:** Sandra Aibangbee  
**Student ID:** 2026/A/MIT/0301/301897710  
**Course:** MIT 8103 Advanced Database Systems  
**Case Study:** KoraPay Wallet (Simulated Nigerian Digital Wallet Platform)  
**Submission Date:** October 2026  

---

## 1. Project Overview and Case Study Summary

This portfolio milestone documents the conceptual, logical, and physical database design for **KoraPay Wallet**, a simulated Nigerian digital wallet platform engineered for academic evaluation. The platform models peer-to-peer money transfers, deposits, withdrawals, and reversals denominated strictly in Nigerian Naira (`NGN`).

The core database architecture consists of four relational tables designed to ensure financial integrity, auditability, and concurrency safety:

1. **`customers`:** Stores customer profile data, contact information, and simulated KYC verification status (`PENDING`, `VERIFIED`, `SUSPENDED`).
2. **`wallets`:** Stores digital wallets (`NGN`), tracking real-time operational status (`ACTIVE`, `FROZEN`, `CLOSED`) and a cached balance. Includes customer-owned wallets and a single platform-level **System Clearing Wallet** (`wallet_type = 'SYSTEM_CLEARING'`) that acts as the counterparty for simulated deposits and withdrawals.
3. **`transactions`:** Records payment intent, transaction types (`TRANSFER`, `DEPOSIT`, `WITHDRAWAL`, `REVERSAL`), participating wallets, idempotency references, and lifecycle states (`PENDING`, `SUCCESSFUL`, `FAILED`, `REVERSED`).
4. **`ledger_entries`:** The intended append-only financial journal. Each row records a `DEBIT` (money out) or `CREDIT` (money in) against a wallet with a point-in-time balance snapshot (`balance_after`). The design intends every successful fund movement to write balanced debit and credit entries, but balanced posting and ledger immutability are proposed controls for later milestones and are not yet enforced (see Section 6).

---

## 2. Directory Navigation and Artifact Links

All deliverables for Milestone 1 are organized within this folder using the following structure:

### Documentation
- [**Case Study Specification (`case-study.md`)**](./case-study.md): Comprehensive functional requirements, business rules, and project boundaries.
- [**Database Design Document (`database-design.md`)**](./database-design.md): Full relational schema specification, Mermaid ER diagram, relationship cardinalities, transaction boundaries, and glossary.
- [**Database Normalisation Report (`normalisation.md`)**](./normalisation.md): Step-by-step normalisation analysis (UNF to 3NF), candidate key evaluation, modification anomaly analysis, and deliberate denormalisation rationale.

### SQL Scripts
- [**`Aibangbee_Sandra_2026_A_MIT_0301_301897710_CreateDatabase.sql`**](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_CreateDatabase.sql): Script to initialize the standalone `korapay_wallet` database.
- [**`Aibangbee_Sandra_2026_A_MIT_0301_301897710_01_VerifySetup.sql`**](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_01_VerifySetup.sql): Script to verify database connection, PostgreSQL version, and current schema environment.
- [**`Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql`**](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql): Core DDL script creating the four tables, constraints, foreign keys (`ON DELETE RESTRICT`), and partial unique indexes wrapped in `BEGIN ... COMMIT`.
- [**`Aibangbee_Sandra_2026_A_MIT_0301_301897710_03_ConstraintTests.sql`**](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_03_ConstraintTests.sql): Comprehensive test suite executing 16 constraint tests and post-test data state verification.

### Diagram
- [**Entity-Relationship (ER) Diagram Image**](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_ERDiagram.png): Graphical rendering of the four core tables, relationships, and constraints.

---

## 3. Database Setup and Execution Guide in pgAdmin

To replicate the schema and execute the constraint tests in **pgAdmin 4**:

### Step 1: Database Creation
1. Open pgAdmin 4 and connect to your local PostgreSQL server instance.
2. If a database named **`korapay_wallet`** already exists, skip the rest of this step and go to Step 2.
3. Otherwise, open the Query Tool against the default maintenance database (`postgres`) and run [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_CreateDatabase.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_CreateDatabase.sql) **once**:
   ```sql
   CREATE DATABASE korapay_wallet;
   ```

### Step 2: Verify the Connection
1. In pgAdmin, open a Query Tool connected to the **`korapay_wallet`** database (not `postgres`).
2. Run [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_01_VerifySetup.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_01_VerifySetup.sql) and confirm that the current database is `korapay_wallet`.

### Step 3: Schema Creation
1. In the same `korapay_wallet` Query Tool, open [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql).
2. Execute the entire script **once**, against an empty schema (one that does not yet contain the four tables). The script is wrapped in a `BEGIN; ... COMMIT;` block and creates the four core tables, constraints, foreign keys, and partial unique indexes. Running it a second time will fail because the tables already exist.

### Step 4: Running the Constraint Tests
1. Open [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_03_ConstraintTests.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_03_ConstraintTests.sql) in the Query Tool against `korapay_wallet`.
2. **Execute Statements Individually:**
   - Do **NOT** run the entire file as a single batch.
   - The test statements intentionally contain invalid data designed to trigger specific constraint rejections. Running the entire script at once will abort at the first error.
   - Highlight each individual constraint test and click **Execute**.
3. **Important Execution Rules:**
   - **Run Setup Inserts Once:** The setup `INSERT` blocks (valid customers, valid wallets, and pending transaction) populate the baseline rows and must be run only once. If rerun against an already populated database, they will fail with unique constraint violations.
   - **Use the IDs Actually Returned:** Surrogate IDs (`customer_id`, `wallet_id`, `transaction_id`) come from sequences and depend on the database's history, so they may differ between sessions. Check the IDs returned by the setup inserts and use those values in the tests that reference them. In the documented test session, the valid customer wallets received IDs `4` and `5`, the system clearing wallet received ID `6`, and the valid pending transaction received ID `3`.

---

## 4. Constraint Test Suite Summary and Screenshot Evidence

The schema enforces strict domain rules, referential integrity, and business invariants at the database engine layer. Below is a complete summary of the 16 constraint tests executed in PostgreSQL, the expected rejections, and direct links to the screenshot evidence captured during execution:

| Test # | Target Table & Constraint | Test Statement / Condition | Expected Database Rejection | Screenshot Evidence Link |
| :---: | :--- | :--- | :--- | :--- |
| **01** | `customers`<br>`uq_customers_email` | Attempt to insert a second customer with existing email (`ada.test@example.com`). | `ERROR: duplicate key value violates unique constraint "uq_customers_email"` | [Screenshot Test 01](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test01_DuplicateEmail.png) |
| **02** | `customers`<br>`uq_customers_phone_number` | Attempt to insert a customer with an existing phone number (`08011111111`). | `ERROR: duplicate key value violates unique constraint "uq_customers_phone_number"` | [Screenshot Test 02](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test02_DuplicatePhone.png) |
| **03** | `customers`<br>`chk_customers_verification_status` | Attempt to insert a customer with invalid verification status (`'APPROVED'`). | `ERROR: new row for relation "customers" violates check constraint "chk_customers_verification_status"` | [Screenshot Test 03](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test03_InvalidVerificationStatus.png) |
| **04** | `wallets`<br>`chk_wallets_balance` | Attempt to create a customer wallet with a negative balance (`-100.00`). | `ERROR: new row for relation "wallets" violates check constraint "chk_wallets_balance"` | [Screenshot Test 04](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test04_NegativeBalance.png) |
| **05** | `wallets`<br>`fk_wallets_customer` | Attempt to create a wallet referencing a nonexistent customer (`customer_id = 999999`). | `ERROR: insert or update on table "wallets" violates foreign key constraint "fk_wallets_customer"` | [Screenshot Test 05](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test05_InvalidCustomer.png) |
| **06** | `wallets`<br>`chk_wallets_customer_ownership` | Attempt to create a customer wallet (`wallet_type = 'CUSTOMER'`) with `customer_id = NULL`. | `ERROR: new row for relation "wallets" violates check constraint "chk_wallets_customer_ownership"` | [Screenshot Test 06](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test06_MissingWalletOwner.png) |
| **07** | `wallets`<br>`uq_wallets_customer_id` | Attempt to provision a second wallet for Customer 1 (`UNIQUE (customer_id)` violation). | `ERROR: duplicate key value violates unique constraint "uq_wallets_customer_id"` | [Screenshot Test 07](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test07_SecondCustomerWallet.png) |
| **08** | `wallets`<br>`uq_single_system_clearing_wallet` | Attempt to insert a second system clearing wallet (`wallet_type = 'SYSTEM_CLEARING'`). | `ERROR: duplicate key value violates unique constraint "uq_single_system_clearing_wallet"` | [Screenshot Test 08](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test08_SecondClearingWallet.png) |
| **09** | `transactions`<br>`chk_transactions_amount` | Attempt to record a transaction with an amount of `0.00`. | `ERROR: new row for relation "transactions" violates check constraint "chk_transactions_amount"` | [Screenshot Test 09](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test09_ZeroAmount.png) |
| **10** | `transactions`<br>`chk_transactions_distinct_wallets` | Attempt to transfer funds where `source_wallet_id = destination_wallet_id` (Wallet 4 to 4). | `ERROR: new row for relation "transactions" violates check constraint "chk_transactions_distinct_wallets"` | [Screenshot Test 10](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test10_SameWallet.png) |
| **11** | `transactions`<br>`uq_transactions_reference` | Attempt to insert a second transaction with an existing reference (`test-reference-001`). | `ERROR: duplicate key value violates unique constraint "uq_transactions_reference"` | [Screenshot Test 11](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test11_DuplicateReference.png) |
| **12** | `transactions`<br>`chk_transactions_reversal_rule` | Attempt to record a `'REVERSAL'` without linking an original transaction ID. | `ERROR: new row for relation "transactions" violates check constraint "chk_transactions_reversal_rule"` | [Screenshot Test 12](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test12_MissingReversalOriginal.png) |
| **13** | `ledger_entries`<br>`chk_ledger_entries_entry_type` | Attempt to insert a ledger entry with an invalid entry type (`'OTHER'`). | `ERROR: new row for relation "ledger_entries" violates check constraint "chk_ledger_entries_entry_type"` | [Screenshot Test 13](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test13_InvalidLedgerType.png) |
| **14** | `ledger_entries`<br>`chk_ledger_entries_amount` | Attempt to write a ledger line with an amount of `0.00`. | `ERROR: new row for relation "ledger_entries" violates check constraint "chk_ledger_entries_amount"` | [Screenshot Test 14](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test14_ZeroLedgerAmount.png) |
| **15** | `ledger_entries`<br>`fk_ledger_entries_transaction` | Attempt to link a ledger entry to a nonexistent transaction (`transaction_id = 999999`). | `ERROR: insert or update on table "ledger_entries" violates foreign key constraint "fk_ledger_entries_transaction"` | [Screenshot Test 15](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test15_InvalidLedgerTransaction.png) |
| **16** | `wallets`<br>`chk_wallets_currency` | Attempt to update an existing wallet's currency from `'NGN'` to `'USD'`. | `ERROR: new row for relation "wallets" violates check constraint "chk_wallets_currency"` | [Screenshot Test 16](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_Test16_InvalidCurrency.png) |

*Evidence Audit Note:* All 16 screenshot links above were checked against the filenames in the [`screenshots/`](./screenshots/) directory, and every file is present. This filename check confirms only that each evidence file exists; the test results themselves (the rejection messages returned by PostgreSQL) are shown in the contents of each screenshot.

---

## 5. Observed Post-Test Database State

Following the completion of the 16 constraint tests, the verification query in [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_03_ConstraintTests.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_03_ConstraintTests.sql) was executed to audit the stored data:

```sql
SELECT
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM wallets) AS wallets,
    (SELECT COUNT(*) FROM transactions) AS transactions,
    (SELECT COUNT(*) FROM ledger_entries) AS ledger_entries,
    (SELECT COUNT(*) FROM wallets WHERE currency <> 'NGN') AS non_ngn_wallets,
    (SELECT SUM(balance) FROM wallets) AS total_wallet_balance;
```

### Observed Results:
- **`customers`:** `2` (Ada Obi, Bola Ade from setup).
- **`wallets`:** `3` (Ada's wallet, Bola's wallet, and 1 system clearing wallet).
- **`transactions`:** `1` (`test-reference-001`, recorded with status `'PENDING'`).
- **`ledger_entries`:** `0` (No money movements occurred; no ledger rows were written).
- **`non_ngn_wallets`:** `0` (100% of wallets strictly conform to `'NGN'`).
- **`total_wallet_balance`:** `0.00` (All balances remain strictly at baseline).

Screenshot verification: [**`Aibangbee_Sandra_2026_A_MIT_0301_301897710_PostTestVerification.png`**](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_PostTestVerification.png).

---

## 6. Scope Boundaries: Schema Constraints vs. Proposed Controls

It is critical to distinguish between what was validated in Milestone 1 and what remains proposed for subsequent milestones:

- **What Milestone 1 Validates:**
  - Relational table definitions, primary keys, and foreign keys with `ON DELETE RESTRICT`.
  - Static database constraints (`NOT NULL`, `UNIQUE`, domain `CHECK` constraints).
  - Partial unique indexes restricting system clearing wallets (`<= 1`) and reversals (`<= 1`).
  - Rejection of corrupt or invalid data at the PostgreSQL engine level.

- **What Remains Proposed for Future Milestones:**
  - **Balanced Money Posting:** Enforcing that every successful transaction writes *exactly two balanced ledger entries* (one DEBIT, one CREDIT of equal amount) requires procedural posting logic (e.g., PL/pgSQL stored procedures).
  - **Pessimistic Concurrency Locking:** Acquiring row-level locks on both wallets in ascending `wallet_id` order (`SELECT ... FOR UPDATE`) to prevent stale balance overspending and reduce deadlocks.
  - **Complete Idempotency Workflow:** Application logic that checks existing request references, verifies that request payloads match the original record, and handles retry responses without querying inside aborted transactions.
  - **Ledger Immutability:** Revoking direct `INSERT`, `UPDATE`, and `DELETE` permissions on `ledger_entries` from application database roles to guarantee an append-only audit journal.
  - **Balance Reconciliation:** Automated batch queries comparing cached wallet balances against net historical ledger sums.

> [!IMPORTANT]
> **Complete money posting does not yet exist in Milestone 1.** Milestone 1 establishes the verified relational schema and constraint boundaries. Fund execution, concurrency controls, and ledger immutability will be implemented in subsequent portfolio milestones.

---

## 7. AI Assistance Declaration

In accordance with academic integrity guidelines, the following declaration discloses the nature and extent of artificial intelligence tools used during Portfolio Milestone 1:

- **AI Tools Used:** OpenAI ChatGPT, Google Antigravity Agent, and Anthropic Claude.
- **Scope of AI Assistance:**
  - **ChatGPT and Antigravity** assisted with drafting the documentation and SQL scripts, and with reviewing and interpreting the test results.
  - **Claude** assisted with the final edits to this documentation.
- **Student Contribution:**
  - The student (**Sandra Aibangbee**) executed the SQL scripts locally in PostgreSQL and pgAdmin 4 and captured the evidence screenshots.

---

## 8. Student Reflection

### Prompt 1: Double-Entry Design vs. Simple Account Tables
> *Reflect on the design challenges of modeling a financial ledger with paired debit/credit entries compared to simply updating a single balance column. What are the key trade-offs in terms of auditability, storage overhead, and application complexity?*  
> **Student Notes / Reflection:**  
> I learned that storing only a wallet balance does not explain the transactions behind it. Paired debit and credit entries provide a history that helps trace money movements and investigate discrepancies. This requires more storage and more complex posting logic because both entries and the wallet balances must be updated together. My current schema defines the ledger structure, but complete money posting has not yet been implemented.

### Prompt 2: Database Engine Constraints vs. Application Logic
> *Reflect on which business rules are best enforced directly in PostgreSQL (e.g., `CHECK`, `UNIQUE`, foreign keys) versus those that must be handled by application transactions or stored procedures. Where does the boundary lie, and what happens when that boundary is breached?*  
> **Student Notes / Reflection:**  
> I learned that database constraints protect stored data by rejecting entries that break defined rules. PostgreSQL rejected duplicate emails, negative customer wallet balances and wallets linked to nonexistent customers. These expected errors showed that the constraints worked. However, completing a transfer requires additional transaction logic to update both wallets and write matching ledger entries together.

### Prompt 3: Normalisation in Theory vs. Real-World Practice
> *Reflect on the process of converting the unnormalised transfer sheet to 3NF. How does the deliberate denormalisation of storing `amount` on ledger entries and caching `wallets.balance` reconcile with formal database theory? Why is pure academic 3NF sometimes adapted in high-throughput financial architectures?*  
> **Student Notes / Reflection:**  
> I learned that normalisation reduces repeated data and helps prevent inconsistent updates. Separating customers, wallets, transactions and ledger entries gives each table a clear purpose. Storing the wallet balance and repeating the transaction amount in ledger entries are deliberate design choices that support quick balance checks and useful journal records. However, these stored values can become inconsistent, so the proposed posting logic and reconciliation checks must keep them aligned.

### Prompt 4: Concurrency and Race Condition Hazards
> *Reflect on what you learned about race conditions, lost updates, and stale balance reads. Why was it important to understand that PostgreSQL Read Committed prevents dirty reads but does not automatically prevent double-spending without explicit row locking?*  
> **Student Notes / Reflection:**  
> I understand that two transfers could read the same available balance before either finishes, allowing both to approve spending against the same money. Read Committed prevents dirty reads, but a separate balance check and update can still use an outdated balance. The proposed solution is to lock both participating wallets in ascending wallet ID order, check the available funds and complete the updates within one transaction. I have not yet implemented or tested this concurrency control.
