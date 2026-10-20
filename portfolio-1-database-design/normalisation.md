# KoraPay Wallet — Database Normalisation Report

**Course:** MIT 8103 Advanced Database Systems  
**Student:** Sandra Aibangbee  
**Student ID:** 2026/A/MIT/0301/301897710  
**Portfolio Milestone:** 1 — Database Design and Modelling  
**Case Study Reference:** [case-study.md](./case-study.md)  
**Schema Implementation Reference:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql)  
**Status:** Academic Documentation (Design and Normalisation Analysis)

---

## 1. Introduction and Objectives

Normalisation is a formal database design technique used to organize relational tables to minimize data redundancy, prevent modification anomalies (insertion, update, and deletion anomalies), and ensure that data dependencies are logical and consistent.

In **KoraPay Wallet**, a simulated Nigerian digital wallet platform, financial accuracy, auditability, and concurrency safety are paramount. This document provides a step-by-step normalisation analysis demonstrating how the platform's four core tables—`customers`, `wallets`, `transactions`, and `ledger_entries`—were derived from an unnormalised state through First Normal Form (1NF), Second Normal Form (2NF), and Third Normal Form (3NF).

Furthermore, this report:
- Assesses **all candidate keys**, including natural alternate keys and the composite candidate key `{transaction_id, entry_type}` on the financial ledger.
- Provides a mathematically sound evaluation of the relationship between customers and wallets without relying on misleading transitive dependency claims.
- Explains that the presence of `amount` in `ledger_entries` is a **deliberate departure from strict 2NF and strict 3NF** under the proposed equal-amount posting rule.
- Identifies **deliberately stored derived values** (`wallets.balance`, `ledger_entries.balance_after`), explaining their consistency requirements.
- Distinguishes clearly between what is enforced by the **implemented schema constraints** and what remains **proposed posting logic and permissions** for subsequent portfolio milestones.

---

## 2. The Unnormalised Form (UNF): A Concrete Example

In an unnormalised environment, financial platforms often record customer profiles, wallet accounts, transaction requests, and ledger entries inside a single monolithic spreadsheet or flat file.

Below is a fictional unnormalised record (`UNNORMALISED_WALLET_SHEET`) representing customer onboarding and wallet transfers:

### Table 2.1: Monolithic Unnormalised Wallet Sheet (UNF)

| CustomerName | CustomerEmail | CustomerPhone | WalletNumber | Currency | WalletBalance | TransferRef | TransferType | SourceWallet | DestWallet | Amount | Status | LedgerLines (Repeating Group) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Ada Obi | ada@example.com | 08011111111 | W-101 | NGN | 43000.00 | TXN-901<br>TXN-902 | TRANSFER<br>TRANSFER | W-101<br>W-101 | W-202<br>W-303 | 5000.00<br>2000.00 | SUCCESSFUL<br>SUCCESSFUL | {DEBIT, W-101, 5000.00, 45000.00; CREDIT, W-202, 5000.00, 15000.00}<br>{DEBIT, W-101, 2000.00, 43000.00; CREDIT, W-303, 2000.00, 2000.00} |
| Bola Ade | bola@example.com | 08022222222 | W-202 | NGN | 15000.00 | TXN-901 | TRANSFER | W-101 | W-202 | 5000.00 | SUCCESSFUL | {DEBIT, W-101, 5000.00, 45000.00; CREDIT, W-202, 5000.00, 15000.00} |
| Chi Eze | chi@example.com | 08033333333 | W-303 | NGN | 2000.00 | TXN-902 | TRANSFER | W-101 | W-303 | 2000.00 | SUCCESSFUL | {DEBIT, W-101, 2000.00, 43000.00; CREDIT, W-303, 2000.00, 2000.00} |
| System Clearing | *NULL* | *NULL* | W-999 | NGN | -50000.00 | TXN-801 | DEPOSIT | W-999 | W-101 | 50000.00 | SUCCESSFUL | {DEBIT, W-999, 50000.00, -50000.00; CREDIT, W-101, 50000.00, 50000.00} |

> [!NOTE]
> The financial data shown in Table 2.1 and Table 3.1 is an **illustrative extract with stated opening balances**, designed to demonstrate repeating groups, partial dependencies, and normalisation mechanics. It does not represent the platform's executed seed data or a complete funding history.

### Structural Flaws in the Unnormalised Design:
1. **Repeating Groups:** A single row contains multiple transaction requests, and each transaction contains a nested collection of ledger entries.
2. **Entangled Entity Levels:** Identity data, account states, transfer requests, and accounting journal lines are mixed within the same record.
3. **Modification Anomalies:** Inserting, updating, or deleting any business record requires handling inconsistent repeating structures.

---

## 3. Step-by-Step Conversion: 1NF to 3NF

### 3.1 First Normal Form (1NF)

**Formal Definition of 1NF:**  
A relation is in First Normal Form (1NF) if and only if:
1. Every attribute contains only **atomic (indivisible) scalar values** relative to the relational domain (no repeating groups, arrays, or nested sets).
2. Each tuple is uniquely identifiable by an established primary key.

#### Conversion from UNF to 1NF:
To convert Table 2.1 into 1NF, we eliminate the repeating groups by flattening the data so that **each row represents exactly one transaction entry**. Each row explicitly identifies the specific wallet affected by that entry (`EntryWallet`) and its resulting balance snapshot (`BalanceAfter`).

### Table 3.1: Flattened 1NF Representation (FLATTENED_TRANSACTION_LOG)

| RowID (PK) | TransferRef | EntryType | EntryWallet | WalletOwner | OwnerEmail | OwnerPhone | TransferType | SourceWallet | DestWallet | Amount | BalanceAfter | Status |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | TXN-901 | DEBIT | W-101 | Ada Obi | ada@example.com | 08011111111 | TRANSFER | W-101 | W-202 | 5000.00 | 45000.00 | SUCCESSFUL |
| 2 | TXN-901 | CREDIT | W-202 | Bola Ade | bola@example.com | 08022222222 | TRANSFER | W-101 | W-202 | 5000.00 | 15000.00 | SUCCESSFUL |
| 3 | TXN-902 | DEBIT | W-101 | Ada Obi | ada@example.com | 08011111111 | TRANSFER | W-101 | W-303 | 2000.00 | 43000.00 | SUCCESSFUL |
| 4 | TXN-902 | CREDIT | W-303 | Chi Eze | chi@example.com | 08033333333 | TRANSFER | W-101 | W-303 | 2000.00 | 2000.00 | SUCCESSFUL |

#### Observations on Table 3.1:
- Every row contains atomic values without nested arrays or lists.
- Each transaction entry has exactly one row.
- Each `(TransferRef, EntryType)` pair is unique across the table (e.g., Row 1 is `(TXN-901, DEBIT)` and Row 2 is `(TXN-901, CREDIT)`).
- The balances and amounts are completely consistent with the stated opening balances:
  - Ada Obi (W-101) began at ₦50,000.00. After TXN-901 (₦5,000.00 debit), W-101 balance was ₦45,000.00. After TXN-902 (₦2,000.00 debit), W-101 balance was ₦43,000.00.
  - Bola Ade (W-202) began at ₦10,000.00. After TXN-901 (₦5,000.00 credit), W-202 balance was ₦15,000.00.
  - Chi Eze (W-303) began at ₦0.00. After TXN-902 (₦2,000.00 credit), W-303 balance was ₦2,000.00.

#### Clarification on Name Splitting:
In KoraPay Wallet, customer names are divided into `first_name` and `last_name`. **Splitting names is an application design choice, not a strict requirement of 1NF**:
- An attribute is atomic if the relational database treats it as a single indivisible unit. A full name string such as `"Ada Obi"` is fully atomic in relational database theory.
- We separate names into `first_name` and `last_name` to facilitate search indexing, sorting, and user greeting templates, but the table satisfies 1NF regardless of whether names are split or combined.

---

### 3.2 Second Normal Form (2NF)

**Formal Definition of 2NF:**  
A relation is in Second Normal Form (2NF) if and only if:
1. It is already in 1NF.
2. Every non-prime attribute is **fully functionally dependent on every candidate key** (there are no partial functional dependencies on a proper subset of any composite candidate key).

#### Surrogate Keys and 2NF:
A critical principle of relational theory is that **introducing a single-column surrogate primary key (such as `RowID`) does not automatically make a relation 2NF**. 2NF requires assessing **every candidate key**.

In Table 3.1, in addition to `RowID`, there is a natural composite candidate key:
- `Candidate Key = {TransferRef, EntryType}`

#### Identifying Partial Functional Dependencies:
A partial functional dependency occurs when a non-prime attribute depends on only a proper subset of a composite candidate key:
1. `TransferRef` is a proper subset of `{TransferRef, EntryType}`.
2. The transaction details (`TransferType`, `SourceWallet`, `DestWallet`, `Amount`, `Status`) depend solely on `TransferRef`:
   `TransferRef -> {TransferType, SourceWallet, DestWallet, Amount, Status}`
Because these attributes do not depend on `EntryType`, this is a **partial functional dependency**, which violates 2NF.

*(Note: In contrast, the relationship `EntryWallet -> WalletOwner, OwnerEmail, OwnerPhone` is not a partial dependency on `{TransferRef, EntryType}`, because `EntryWallet` is not a subset of that composite candidate key; it represents a functional dependency between non-key attributes to be resolved during further decomposition).*

#### Intermediate 2NF Decomposition:
To resolve this partial dependency, we decompose Table 3.1 into three intermediate relations:

1. **`TRANSACTIONS_2NF`** (Transaction-level facts):
   - **Candidate Key:** `{TransferRef}`
   - **Attributes:** `TransferRef`, `TransferType`, `SourceWallet`, `DestWallet`, `Amount`, `Status`.
   - **Dependencies:** All attributes depend fully on `TransferRef`.

2. **`LEDGER_LINES_2NF`** (Entry-level facts):
   - **Candidate Key:** `{TransferRef, EntryType}`
   - **Attributes:** `TransferRef`, `EntryType`, `EntryWallet`, `BalanceAfter`.
   - **Dependencies:** Both `TransferRef` and `EntryType` are required together to determine which wallet was affected (`EntryWallet`) and its resulting balance snapshot (`BalanceAfter`).

3. **`ACCOUNTS_2NF`** (Account-level facts):
   - **Candidate Key:** `{EntryWallet}`
   - **Attributes:** `EntryWallet`, `WalletOwner`, `OwnerEmail`, `OwnerPhone`.
   - **Dependencies:** Account and customer attributes depend on `EntryWallet`.

This intermediate decomposition completely eliminates partial functional dependencies on `{TransferRef, EntryType}`.

---

### 3.3 Third Normal Form (3NF)

**Formal Definition of 3NF:**  
A relation is in Third Normal Form (3NF) if and only if it is in 2NF and, for every non-trivial functional dependency $X \rightarrow A$, either:
1. $X$ is a **superkey**, or
2. $A$ is a **prime attribute** (a member of some candidate key).

In simple terms, non-prime attributes must depend strictly on candidate keys and cannot depend on other non-key attributes (no transitive dependencies).

#### Entity Separation into Final Relations:
In `ACCOUNTS_2NF`, customer identity attributes (`WalletOwner`, `OwnerEmail`, `OwnerPhone`) exist alongside wallet accounts. Under our strict **one-wallet-per-customer rule**, separating `customers` and `wallets` is not strictly required by 3NF to eliminate a transitive dependency (since a customer owns at most one wallet, creating a 1-to-1 functional correspondence where `customer_id` and `wallet_id` determine each other; see the detailed candidate key analysis in [Section 4.2](#42-table-wallets)).

Rather, the separation of `customers` and `wallets` into distinct tables is justified by:
1. **Distinct Entity Boundaries:** Customers represent natural or legal persons with personal profile and KYC attributes, whereas wallets represent operational financial ledger accounts.
2. **Registration Lifecycle:** Separating them allows the customer profile and their initial wallet to be co-provisioned cleanly within application transactions while decoupling identity modifications from balance operations.
3. **The Ownerless System Clearing Wallet:** The platform requires a dedicated system clearing wallet (`wallet_type = 'SYSTEM_CLEARING'`) that has no customer owner (`customer_id IS NULL`). Merging customers and wallets would force the system clearing account to store dummy customer data or violate `NOT NULL` constraints on personal identity attributes (`first_name`, `last_name`, `email`, `phone_number`).

Along with `transactions` and `ledger_entries`, this yields the final four-table architecture.

---

## 4. Comprehensive Functional Dependency and Candidate Key Analysis

### 4.1 Table: `customers`

- **Attributes:** `customer_id`, `first_name`, `last_name`, `email`, `phone_number`, `verification_status`, `created_at`, `updated_at`.
- **Candidate Keys:**
  1. `{customer_id}` (Surrogate Primary Key)
  2. `{email}` (Alternate Candidate Key)
  3. `{phone_number}` (Alternate Candidate Key)
- **Functional Dependencies:**
  - `customer_id -> first_name, last_name, email, phone_number, verification_status, created_at, updated_at`
  - `email -> customer_id, first_name, last_name, phone_number, verification_status, created_at, updated_at`
  - `phone_number -> customer_id, first_name, last_name, email, verification_status, created_at, updated_at`
- **3NF Evaluation:** For every non-trivial functional dependency $X \rightarrow A$, $X$ is a superkey. No transitive dependencies exist. `customers` is in strict 3NF.

---

### 4.2 Table: `wallets`

- **Attributes:** `wallet_id`, `customer_id`, `wallet_number`, `wallet_type`, `currency`, `balance`, `status`, `created_at`, `updated_at`.
- **Candidate Keys:**
  1. `{wallet_id}` (Surrogate Primary Key)
  2. `{wallet_number}` (Alternate Candidate Key)
- **Status of `customer_id` (Conditional Unique Identifier):**
  - In KoraPay Wallet, `wallets.customer_id` has a `UNIQUE` constraint to enforce that a customer owns at most one wallet.
  - However, in formal relational theory, **a candidate key must be non-null across the entire relation**. Because the System Clearing Wallet has no customer owner (`customer_id IS NULL`), `customer_id` cannot serve as a relation-wide candidate key. It is formally classified as a **conditional unique identifier** for customer wallets.
- **Functional Dependencies:**
  - `wallet_id -> customer_id, wallet_number, wallet_type, currency, balance, status, created_at, updated_at`
  - `wallet_number -> wallet_id, customer_id, wallet_type, currency, balance, status, created_at, updated_at`
- **Evaluation of Customer-to-Wallet Separation:**
  - In introductory database texts, it is sometimes claimed that storing customer attributes inside `wallets` creates a transitive dependency:
    `wallet_id -> customer_id -> email`
  - In KoraPay Wallet, because each customer has at most one wallet, there is a 1-to-1 functional correspondence between `customer_id` and `wallet_id` for customer-owned wallets (`customer_id <-> wallet_id`). When the intermediate determinant is a candidate identifier, it does not constitute a formal 3NF violation.
  - **Sound Justifications for Separating Customers and Wallets:**
    1. **Entity Decoupling:** Customers represent legal human or business entities; wallets represent monetary accounts.
    2. **Handling the System Clearing Wallet:** Merging customers and wallets would force the system clearing account (`wallet_type = 'SYSTEM_CLEARING'`) to store dummy customer data or violate `NOT NULL` constraints on personal identity attributes (`first_name`, `last_name`, `email`, `phone_number`).
    3. **Architectural Extensibility:** Isolating wallets enables future platform growth (such as introducing foreign currency wallets per customer) without modifying the customer entity.

---

### 4.3 Table: `transactions`

- **Attributes:** `transaction_id`, `reference`, `transaction_type`, `source_wallet_id`, `destination_wallet_id`, `amount`, `status`, `reversal_of_transaction_id`, `description`, `created_at`.
- **Candidate Keys:**
  1. `{transaction_id}` (Surrogate Primary Key)
  2. `{reference}` (Alternate Candidate Key / Client Idempotency Key)
- **Functional Dependencies:**
  - `transaction_id -> reference, transaction_type, source_wallet_id, destination_wallet_id, amount, status, reversal_of_transaction_id, description, created_at`
  - `reference -> transaction_id, transaction_type, source_wallet_id, destination_wallet_id, amount, status, reversal_of_transaction_id, description, created_at`
- **3NF Evaluation:** Both `{transaction_id}` and `{reference}` are superkeys. All non-key attributes depend directly on these keys. `transactions` is in strict 3NF.

---

### 4.4 Table: `ledger_entries`

- **Attributes:** `ledger_entry_id`, `transaction_id`, `wallet_id`, `entry_type`, `amount`, `balance_after`, `created_at`.
- **Candidate Keys:**
  1. `{ledger_entry_id}` (Surrogate Primary Key)
  2. `{transaction_id, entry_type}` (Composite Candidate Key, enforced by `UNIQUE (transaction_id, entry_type)`)
- **Functional Dependencies:**
  - `ledger_entry_id -> transaction_id, wallet_id, entry_type, amount, balance_after, created_at`
  - `{transaction_id, entry_type} -> ledger_entry_id, wallet_id, amount, balance_after, created_at`
- **Deliberate Departure from Strict 2NF and 3NF:**
  - Under the platform's intended equal-amount posting rule, every successful transaction generates two ledger entries with amounts equal to the transaction amount:
    `transaction_id -> amount`
  - Because `transaction_id` is a proper subset of the composite candidate key `{transaction_id, entry_type}`, this dependency represents a **partial functional dependency** on `{transaction_id, entry_type}`.
  - Consequently, storing `amount` in `ledger_entries` is a **deliberate departure from strict 2NF and therefore strict 3NF**.
  - **Proposed Nature of This Rule:** This equal-amount relationship is an intended posting rule; it is **not enforced by the current DDL schema** (the DDL enforces only `amount > 0` and `UNIQUE(transaction_id, entry_type)`).
  - **Why Redundancy Is Retained:** Retaining `amount` makes each ledger entry self-contained. Audit summaries, statement exports, and balance calculations can operate directly on `ledger_entries` without requiring a relational join back to `transactions`.
  - For this reason, `ledger_entries` is classified as a **deliberately denormalised ledger**.

---

## 5. Modification Anomalies in Unnormalised Designs

To understand why normalisation is critical for financial platforms, consider the anomalies that plague unnormalised structures (such as Table 2.1 and Table 3.1):

### 5.1 Insertion Anomaly
- **The Problem:** In an unnormalised table combining customer, wallet, and transaction data, a customer cannot be registered unless they immediately perform a financial transfer.
- **Example:** If customer `"Chi Eze"` registers on KoraPay Wallet, the system cannot store her profile details without either inserting `NULL` into transaction fields (`TransferRef`, `Amount`) or inventing dummy transfer records.
- **Normalised Resolution:** Registration should create the customer profile in `customers` and their initial NGN wallet in `wallets` **together in one single atomic transaction**, completely independently of financial fund movements.

### 5.2 Update Anomaly
- **The Problem:** When customer or wallet details are stored redundantly across multiple transaction rows, updating a single fact requires modifying many records simultaneously. If an update is interrupted, data becomes inconsistent.
- **Example:** In Table 3.1, Ada Obi's phone number (`08011111111`) is duplicated across rows 1 and 3. If Ada updates her phone number, the system must update both rows. If an update error occurs midway, different transactions will display conflicting phone numbers for the same customer.
- **Normalised Resolution:** Phone numbers are stored exactly once in `customers`. Updating the customer profile updates all associated records without modifying historical transaction entries.

### 5.3 Deletion Anomaly
- **The Problem:** Deleting one transaction record inadvertently destroys unrelated customer or account data.
- **Example:** In Table 3.1, Chi Eze (Wallet W-303) appears in only one single entry: the CREDIT entry of `TXN-902` (Row 4). If `TXN-902` is cancelled, purged, or deleted from the log (for example, as part of purging test records), deleting that row inadvertently deletes the **only record** of Chi Eze's customer identity and wallet account (`Chi Eze`, `chi@example.com`, `08033333333`, `W-303`).
- **Normalised Resolution:** Deleting or rolling back a transaction in `transactions` leaves the customer record in `customers` and the wallet record in `wallets` completely intact.

---

## 6. Deliberately Stored Derived Values and Redundancy

Pure normalisation theory discourages storing values that can be computed from other attributes. However, real-world financial architectures deliberately introduce **controlled denormalisation** to meet performance and auditability requirements.

In KoraPay Wallet, three values are intentionally stored:

### 6.1 Cached Balance (`wallets.balance`)
- **What it is:** A stored derived value representing the sum of all historical credits minus debits:
  `balance = sum(CREDIT amounts) - sum(DEBIT amounts)`
- **Engineering Justification:** A stored balance **avoids aggregating historical ledger entries for each balance check**. Without a stored balance, every payment request would require scanning and summing thousands or millions of historical ledger records. Storing `wallets.balance` allows rapid balance checks and pessimistic row locking (`SELECT ... FOR UPDATE`) during concurrent transfers.
- **Consistency Requirement:** Because `balance` is derived, every fund transfer must update `wallets.balance` and insert matching `ledger_entries` within the **exact same ACID transaction**. Periodic reconciliation queries are proposed to verify consistency.

### 6.2 Balance Snapshot (`ledger_entries.balance_after`)
- **What it is:** The wallet balance immediately after applying that entry within the posting transaction, which is permanently persisted only if the transaction commits.
- **Engineering Justification:** Provides an immutable audit trail. Financial auditors and dispute resolution workflows can inspect the exact account trajectory at any historical moment without recalculating historical timelines.
- **Governance Note:** True ledger immutability remains **proposed** and is **not currently enforced** by the DDL alone, as standard database table permissions permit updates and deletes until restricted by database security roles.

### 6.3 Repeated Amount (`ledger_entries.amount`)
- **What it is:** Storing the transaction amount on both the debit line and credit line in `ledger_entries`, duplicating `transactions.amount`.
- **Engineering Justification:** Allows ledger auditing, balance reconciliation, and account statement generation to run directly against `ledger_entries` without requiring relational joins to `transactions`.
- **Consistency Requirement:** The proposed posting service must guarantee that both ledger lines match `transactions.amount` exactly.

---

## 7. Schema Constraints vs. Proposed Posting Logic

To maintain academic and technical accuracy, we distinguish between what is **implemented in the current PostgreSQL DDL schema** and what remains **proposed logic for future milestones**:

### 7.1 Implemented Schema Constraints (Current Milestone 1 State)
The DDL script [`Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_02_CreateTables.sql) currently implements:
- **Relational Integrity:** Foreign keys with `ON DELETE RESTRICT` prevent orphaned records and accidental deletions of active accounts.
- **Uniqueness Constraints:**
  - Unique emails, phone numbers, and wallet numbers.
  - At most one wallet per customer via `UNIQUE (customer_id)`.
  - Unique transaction request references via `UNIQUE (reference)`.
  - At most one DEBIT and at most one CREDIT entry per transaction via `UNIQUE (transaction_id, entry_type)`.
- **Specialized Business Constraints:**
  - Customer wallets require `customer_id IS NOT NULL`; system clearing wallet requires `customer_id IS NULL`.
  - Partial unique index `uq_single_system_clearing_wallet` ensures **at most one system clearing wallet**.
  - Partial unique index `uq_single_reversal_per_transaction` ensures **at most one reversal record** per original transaction.
  - Allowed-value check constraints for `verification_status`, `wallet_type`, `currency = 'NGN'`, `status`, `transaction_type`, and `entry_type`.
  - Non-negative balance rule for customer wallets; clearing wallet balance may be negative.
  - Positive amounts (`amount > 0`) on both `transactions` and `ledger_entries`.
  - Distinct source and destination wallets (`source_wallet_id <> destination_wallet_id`).
  - Reversal rule requiring a reversal reference if and only if `transaction_type = 'REVERSAL'`, prohibiting self-reversals.

### 7.2 Boundaries: What Schema Constraints Alone Cannot Enforce
Foreign keys and check constraints establish structural boundaries, but they **cannot**:
1. Enforce that every successful transaction writes **exactly two balanced entries** (they only ensure that at most two are written via `UNIQUE(transaction_id, entry_type)`).
2. Ensure that debit amounts equal credit amounts across different wallet rows.
3. Keep `wallets.balance` mathematically synchronized with the sum of historical ledger rows.
4. Prevent direct, unvalidated modifications to ledger entries.

### 7.3 Proposed Posting Logic and Security Governance (Future Milestones)
Complete, safe fund movements require additional software controls proposed for future milestones:
- **Proposed Controlled Posting Routine:** A dedicated procedure (e.g., PL/pgSQL stored procedure `post_ledger_movement`) that locks both wallets in ascending `wallet_id` order, validates balances and account statuses, writes paired ledger entries atomically, and updates cached wallet balances.
- **Proposed Role-Based Permissions (Least Privilege):** Direct `INSERT`, `UPDATE`, and `DELETE` on `ledger_entries` and direct `UPDATE` on `wallets.balance` will be revoked from application roles, permitting writes strictly through the trusted posting routine (`SECURITY DEFINER`).
- **Proposed Idempotency Protocol:**
  1. **Claim Reference Upfront:** Claim the unique client reference before moving funds by inserting the `transactions` record with status `'PENDING'`.
  2. **Require Retries to Reuse the SAME Reference:** Clients experiencing network timeouts or disconnects must retry using the **exact same reference** (idempotency key) rather than generating a new one.
  3. **Compare Request Details & Reject Mismatches:** On retries, the system queries the existing transaction and compares the request details: `source_wallet_id`, `destination_wallet_id`, and `amount`. Currency is checked through the participating wallets because the `transactions` table has no currency column (both wallets must be verified to have `currency = 'NGN'`). If any request detail mismatches the original record, the request is explicitly rejected with an error (e.g., parameter mismatch / idempotency conflict).
  4. **Handle Unique Conflicts Gracefully:** If a concurrent duplicate request triggers a unique constraint collision on `reference`, handle the conflict without querying inside an aborted transaction (e.g., using `INSERT ... ON CONFLICT (reference) DO NOTHING` or issuing `ROLLBACK` first before opening a clean read transaction to inspect the existing transaction record).
- **Proposed Automated Balance Reconciliation:** Periodic batch queries comparing cached balances against net ledger sums to detect any discrepancies.

> [!IMPORTANT]
> **Complete money posting does not yet exist in Milestone 1.** Milestone 1 implements and validates the structural database schema and constraints. Safe fund execution workflows, locking strategies, and ledger immutability controls will be implemented in subsequent milestones.

---

## 8. Summary of Normalisation Architecture

| Entity Table | Primary Key | Alternate / Candidate Keys | Normal Form Status | Key Design Justification |
| :--- | :--- | :--- | :---: | :--- |
| **`customers`** | `customer_id` | `{email}`, `{phone_number}` | **3NF** | Eliminates identity duplication; allows customer creation independent of financial movements. |
| **`wallets`** | `wallet_id` | `{wallet_number}` | **3NF** | Decouples account state from personal profiles; accommodates system clearing account without null-identity violations. |
| **`transactions`** | `transaction_id` | `{reference}` (Idempotency Key) | **3NF** | Captures payment intent, routing, and idempotency independent of accounting journal lines. |
| **`ledger_entries`** | `ledger_entry_id` | `{transaction_id, entry_type}` | **Deliberately denormalised ledger** | Self-contained double-entry journal lines. Deliberately duplicates `amount` for auditing and reconciliation without joins. |

### Conclusion:
The current database design establishes a normalised relational foundation across `customers`, `wallets`, and `transactions`, combined with a deliberately denormalised ledger in `ledger_entries` to support self-contained financial accounting. While structural integrity is enforced by the implemented PostgreSQL schema constraints, complete transactional guarantees—including balanced double-entry posting, immutable ledger histories, and automated reconciliation—will be realized through the proposed application and stored procedure controls in future milestones.
