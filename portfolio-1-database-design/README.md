# Portfolio 1: Database Design and Modelling

**Student:** Sandra Aibangbee  
**Student ID:** 2026/A/MIT/0301/301897710  
**Course:** MIT 8103 Advanced Database Systems  
**Case Study:** KoraPay Wallet (simulated Nigerian digital wallet platform)  
**Submission Date:** October 2026  

---

## 1. Overview

This portfolio covers the conceptual, logical and physical database design for **KoraPay Wallet**, a simulated Nigerian digital wallet platform. It supports transfers, deposits, withdrawals and reversals in Nigerian naira (`NGN`).

The design has four tables:

1. **`customers`:** customer details and simulated KYC status (`PENDING`, `VERIFIED`, `SUSPENDED`).
2. **`wallets`:** NGN wallets with a status (`ACTIVE`, `FROZEN`, `CLOSED`) and a stored balance. Includes one **system clearing wallet** (`wallet_type = 'SYSTEM_CLEARING'`), which is the other side of simulated deposits and withdrawals.
3. **`transactions`:** one row per request, with its type (`TRANSFER`, `DEPOSIT`, `WITHDRAWAL`, `REVERSAL`), wallets, unique reference and status (`PENDING`, `SUCCESSFUL`, `FAILED`, `REVERSED`).
4. **`ledger_entries`:** the financial journal. Each row is a `DEBIT` (money out) or `CREDIT` (money in) on a wallet, with the balance afterwards (`balance_after`). Writing balanced entries for every movement, and making the ledger unchangeable, are proposed controls; the schema does not enforce them (see Section 6).

---

## 2. Files

### Documents
- [**Case study**](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_CaseStudy.md): requirements, business rules and scope.
- [**Database design**](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_DatabaseDesign.md): tables and columns, ER diagram, relationships, rule-to-constraint mapping, proposed transaction logic and a glossary.
- [**Normalisation report**](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Normalisation.md): UNF to 3NF, candidate keys, anomalies and the deliberate denormalisation.

### SQL scripts (run in this order)
- [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_00_CreateDatabase.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_00_CreateDatabase.sql): creates the `korapay_wallet` database.
- [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_01_VerifySetup.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_01_VerifySetup.sql): shows the PostgreSQL version, current database and current user.
- [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql): creates the four tables, keys, constraints, foreign keys (`ON DELETE RESTRICT`) and partial unique indexes, inside `BEGIN ... COMMIT`.
- [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_03_ConstraintTests.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_03_ConstraintTests.sql): setup inserts, 16 constraint tests and a final check of the stored data.

### Diagram
- [**ER diagram**](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_ERDiagram.png): the four tables, their relationships and constraints.

---

## 3. Running the Scripts in pgAdmin

### Step 1: Create the database
1. Open pgAdmin 4 and connect to your local PostgreSQL server.
2. If **`korapay_wallet`** already exists, go to Step 2.
3. Otherwise, open the Query Tool on the `postgres` database and run [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_00_CreateDatabase.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_00_CreateDatabase.sql) **once**:
   ```sql
   CREATE DATABASE korapay_wallet;
   ```

### Step 2: Check the connection
1. Open a Query Tool on **`korapay_wallet`** (not `postgres`).
2. Run [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_01_VerifySetup.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_01_VerifySetup.sql) and confirm that the current database is `korapay_wallet`.

### Step 3: Create the tables
1. In the same Query Tool, open [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql).
2. Run the whole script **once**, on a schema that does not yet have the four tables. A second run fails because the tables already exist.

### Step 4: Run the constraint tests
1. Open [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_03_ConstraintTests.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_03_ConstraintTests.sql) on `korapay_wallet`.
2. **Run one statement at a time.** Highlight each test and click **Execute**. Do **not** run the whole file: the tests are meant to fail, and the first error would stop the run.
3. **Run the setup inserts once.** The valid customers, wallets and pending transaction are inserted once. Running them again fails with unique-constraint errors.
4. **Use the IDs you actually get.** IDs come from sequences, so they can differ between databases. Use the IDs returned by the setup inserts in the later tests. In the recorded session, the customer wallets got IDs `4` and `5`, the clearing wallet got `6`, and the pending transaction got `3`.

---

## 4. Constraint Test Results and Screenshots

All 16 tests were run in PostgreSQL, and each was rejected with the expected error:

| Test # | Table and constraint | What the test tries | Expected error | Screenshot |
| :---: | :--- | :--- | :--- | :--- |
| **01** | `customers`<br>`uq_customers_email` | A second customer with an existing email (`ada.test@example.com`). | `ERROR: duplicate key value violates unique constraint "uq_customers_email"` | [Test 01](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test01_DuplicateEmail.png) |
| **02** | `customers`<br>`uq_customers_phone_number` | A customer with an existing phone number (`08011111111`). | `ERROR: duplicate key value violates unique constraint "uq_customers_phone_number"` | [Test 02](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test02_DuplicatePhone.png) |
| **03** | `customers`<br>`chk_customers_verification_status` | A customer with the invalid status `'APPROVED'`. | `ERROR: new row for relation "customers" violates check constraint "chk_customers_verification_status"` | [Test 03](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test03_InvalidVerificationStatus.png) |
| **04** | `wallets`<br>`chk_wallets_balance` | A customer wallet with balance `-100.00`. | `ERROR: new row for relation "wallets" violates check constraint "chk_wallets_balance"` | [Test 04](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test04_NegativeBalance.png) |
| **05** | `wallets`<br>`fk_wallets_customer` | A wallet for a customer that does not exist (`customer_id = 999999`). | `ERROR: insert or update on table "wallets" violates foreign key constraint "fk_wallets_customer"` | [Test 05](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test05_InvalidCustomer.png) |
| **06** | `wallets`<br>`chk_wallets_customer_ownership` | A `'CUSTOMER'` wallet with `customer_id = NULL`. | `ERROR: new row for relation "wallets" violates check constraint "chk_wallets_customer_ownership"` | [Test 06](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test06_MissingWalletOwner.png) |
| **07** | `wallets`<br>`uq_wallets_customer_id` | A second wallet for Customer 1. | `ERROR: duplicate key value violates unique constraint "uq_wallets_customer_id"` | [Test 07](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test07_SecondCustomerWallet.png) |
| **08** | `wallets`<br>`uq_single_system_clearing_wallet` | A second `'SYSTEM_CLEARING'` wallet. | `ERROR: duplicate key value violates unique constraint "uq_single_system_clearing_wallet"` | [Test 08](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test08_SecondClearingWallet.png) |
| **09** | `transactions`<br>`chk_transactions_amount` | A transaction for `0.00`. | `ERROR: new row for relation "transactions" violates check constraint "chk_transactions_amount"` | [Test 09](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test09_ZeroAmount.png) |
| **10** | `transactions`<br>`chk_transactions_distinct_wallets` | A transfer from Wallet 4 to Wallet 4. | `ERROR: new row for relation "transactions" violates check constraint "chk_transactions_distinct_wallets"` | [Test 10](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test10_SameWallet.png) |
| **11** | `transactions`<br>`uq_transactions_reference` | A second transaction with reference `test-reference-001`. | `ERROR: duplicate key value violates unique constraint "uq_transactions_reference"` | [Test 11](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test11_DuplicateReference.png) |
| **12** | `transactions`<br>`chk_transactions_reversal_rule` | A `'REVERSAL'` with no original transaction. | `ERROR: new row for relation "transactions" violates check constraint "chk_transactions_reversal_rule"` | [Test 12](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test12_MissingReversalOriginal.png) |
| **13** | `ledger_entries`<br>`chk_ledger_entries_entry_type` | A ledger entry with type `'OTHER'`. | `ERROR: new row for relation "ledger_entries" violates check constraint "chk_ledger_entries_entry_type"` | [Test 13](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test13_InvalidLedgerType.png) |
| **14** | `ledger_entries`<br>`chk_ledger_entries_amount` | A ledger entry for `0.00`. | `ERROR: new row for relation "ledger_entries" violates check constraint "chk_ledger_entries_amount"` | [Test 14](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test14_ZeroLedgerAmount.png) |
| **15** | `ledger_entries`<br>`fk_ledger_entries_transaction` | A ledger entry for a transaction that does not exist (`transaction_id = 999999`). | `ERROR: insert or update on table "ledger_entries" violates foreign key constraint "fk_ledger_entries_transaction"` | [Test 15](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test15_InvalidLedgerTransaction.png) |
| **16** | `wallets`<br>`chk_wallets_currency` | Changing a wallet's currency from `'NGN'` to `'USD'`. | `ERROR: new row for relation "wallets" violates check constraint "chk_wallets_currency"` | [Test 16](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Test16_InvalidCurrency.png) |

The error messages appear in each screenshot. All 16 linked files are present in [`screenshots/`](./screenshots/).

### Other Portfolio 1 screenshots
These are also in [`screenshots/`](./screenshots/). Some show the old filenames and earlier versions of the documents, because they were captured before later edits and renames.

**Setup**

| Screenshot | What it shows |
| :--- | :--- |
| [PostgreSQLServiceRunning](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_PostgreSQLServiceRunning.png) | Windows Services: `postgresql-x64-18` running, startup type Automatic. |
| [DatabaseCreated](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_DatabaseCreated.png) | pgAdmin with `korapay_wallet` in the object tree and a Query Tool open on it. The `CREATE DATABASE` command itself is not shown. |
| [VerifySetup](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_VerifySetup.png) | The verify query: PostgreSQL 18.6, database `korapay_wallet`, user `postgres`. |
| [SchemaExecuted](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_SchemaExecuted.png) | The create-tables script (earlier header) run in pgAdmin: `COMMIT`, "Query returned successfully". |
| [TablesCreated](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_TablesCreated.png) | `information_schema.tables` query listing `customers`, `ledger_entries`, `transactions` and `wallets`. |

**Setup rows used by the tests**

| Screenshot | What it shows |
| :--- | :--- |
| [ValidCustomers](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_ValidCustomers.png) | Setup insert returning customers 1 (Ada) and 2 (Bola), both `PENDING`. |
| [ValidWallets](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_ValidWallets.png) | Setup insert returning wallets 4 and 5 (customers 1 and 2) and 6 (`SYSTEM_CLEARING`), all with balance 0.00. |

**Document editing** (earlier versions, in the Antigravity IDE with its AI assistant panel visible)

| Screenshot | What it shows |
| :--- | :--- |
| [DatabaseDesign](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_DatabaseDesign.png) | An earlier `database-design.md`, which still had the "Design Proposal (No SQL execution…)" status, plus `git push` output. |
| [Normalisation](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_Normalisation.png) | Preview of an earlier `normalisation.md` (Section 3.3, 3NF). |
| [StudentReflection](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_StudentReflection.png) | Preview of the README reflections (Prompts 3 and 4). |

**GitHub**

| Screenshot | What it shows |
| :--- | :--- |
| [GitHubRepositoryCreated](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_GitHubRepositoryCreated.png) | The new `mit-8103-database-portfolio` repository with its initial `README.md` commit. |
| [InitialGitHubPush](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_InitialGitHubPush.png) | The repository after its second commit, "Add KoraPay case study and database design", showing the five portfolio folders. |
| [ConstraintTestsGitHubPush](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_ConstraintTestsGitHubPush.png) | The constraint-tests script open in the IDE, with `git push origin main` output in the terminal. |
| [GitSync](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_GitSync.png) | `git pull --ff-only origin main` reporting "Already up to date". |

---

## 5. Data After the Tests

After the 16 tests, the final query in [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_03_ConstraintTests.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_03_ConstraintTests.sql) checked what was stored:

```sql
SELECT
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM wallets) AS wallets,
    (SELECT COUNT(*) FROM transactions) AS transactions,
    (SELECT COUNT(*) FROM ledger_entries) AS ledger_entries,
    (SELECT COUNT(*) FROM wallets WHERE currency <> 'NGN') AS non_ngn_wallets,
    (SELECT SUM(balance) FROM wallets) AS total_wallet_balance;
```

### Results
- **`customers`:** `2` (Ada Obi and Bola Ade, from the setup).
- **`wallets`:** `3` (Ada's wallet, Bola's wallet and the clearing wallet).
- **`transactions`:** `1` (`test-reference-001`, status `'PENDING'`).
- **`ledger_entries`:** `0` (no money moved).
- **`non_ngn_wallets`:** `0` (every wallet is `'NGN'`).
- **`total_wallet_balance`:** `0.00` (all balances are still zero).

These counts equal the setup rows alone, and no wallet uses a currency other than NGN. This is consistent with all 16 test statements having been rejected.

Screenshot: [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_PostTestVerification.png`](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_PostTestVerification.png).

---

## 6. Tested in Portfolio 1 vs. Proposed

- **Implemented and tested in Portfolio 1:**
  - table definitions, primary keys, and foreign keys with `ON DELETE RESTRICT`;
  - `NOT NULL`, `UNIQUE` and `CHECK` constraints;
  - partial unique indexes allowing at most one clearing wallet and at most one reversal per transaction;
  - PostgreSQL rejecting invalid data (the 16 tests above).

- **Proposed in Portfolio 1, not implemented here:**
  - **Balanced posting:** making every successful transaction write exactly one DEBIT and one CREDIT of equal amount needs posting logic (for example a PL/pgSQL function).
  - **Row locking:** lock both wallets in ascending `wallet_id` order (`SELECT ... FOR UPDATE`) to prevent overspending and reduce deadlocks.
  - **Idempotent retries:** check an existing reference, compare the retried request with the stored row, and avoid querying inside an aborted transaction.
  - **Unchangeable ledger:** revoke direct `INSERT`, `UPDATE` and `DELETE` on `ledger_entries` from the application role.
  - **Reconciliation:** regular queries comparing stored balances with ledger totals.

> [!IMPORTANT]
> **Portfolio 1 does not move money.** It sets up and tests the schema and its constraints only.
>
> *Update:* Portfolio 3 later implemented and tested ascending-`wallet_id` locking, a transfer function with idempotent retries, and reconciliation checks. The permission controls and reversals were not implemented. See the [Portfolio 3 README](../portfolio-3-transactions-concurrency/README.md).

---

## 7. AI Assistance Declaration

- **AI tools used:** OpenAI ChatGPT, Google Antigravity Agent and Anthropic Claude.
- **How they were used:**
  - **ChatGPT and Antigravity** helped draft the documentation and SQL scripts, and helped review and interpret the test results.
  - **Claude** helped with the final edits to this documentation. Later, it simplified the wording of the Portfolio 1 documents and SQL comments, corrected inconsistencies between the design and normalisation documents, and renamed the Portfolio 1 files to a consistent naming standard.
- **My contribution:** I (**Sandra Aibangbee**) ran the SQL scripts in PostgreSQL and pgAdmin 4 and captured the screenshots.

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
