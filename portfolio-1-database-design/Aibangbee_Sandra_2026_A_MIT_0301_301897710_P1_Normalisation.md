# KoraPay Wallet — Database Normalisation Report

**Course:** MIT 8103 Advanced Database Systems  
**Student:** Sandra Aibangbee  
**Student ID:** 2026/A/MIT/0301/301897710  
**Portfolio:** 1 — Database Design and Modelling  
**Case study:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_CaseStudy.md](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_CaseStudy.md)  
**Schema:** [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql)

---

## 1. Introduction

Normalisation organises tables to reduce repeated data and to prevent insertion, update and deletion anomalies.

This report shows how the four KoraPay Wallet tables (`customers`, `wallets`, `transactions` and `ledger_entries`) are derived from one unnormalised sheet, through 1NF, 2NF and 3NF. It also:
- checks **every candidate key**, including the composite key `{transaction_id, entry_type}` on `ledger_entries`;
- explains why customers and wallets are separate tables;
- explains why storing `amount` in `ledger_entries` is a **deliberate departure from 2NF (and therefore 3NF)**;
- identifies the **stored derived values** (`wallets.balance`, `ledger_entries.balance_after`) and what keeps them correct;
- separates what the **schema enforces** from what is **proposed** posting logic and permissions.

---

## 2. The Unnormalised Form (UNF): An Example

Without normalisation, customer details, wallets, transfers and ledger lines might all be kept in one spreadsheet.

The fictional sheet below (`UNNORMALISED_WALLET_SHEET`) shows this:

### Table 2.1: Unnormalised Wallet Sheet (UNF)

| CustomerName | CustomerEmail | CustomerPhone | WalletNumber | Currency | WalletBalance | TransferRef | TransferType | SourceWallet | DestWallet | Amount | Status | LedgerLines (Repeating Group) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Ada Obi | ada@example.com | 08011111111 | W-101 | NGN | 43000.00 | TXN-901<br>TXN-902 | TRANSFER<br>TRANSFER | W-101<br>W-101 | W-202<br>W-303 | 5000.00<br>2000.00 | SUCCESSFUL<br>SUCCESSFUL | {DEBIT, W-101, 5000.00, 45000.00; CREDIT, W-202, 5000.00, 15000.00}<br>{DEBIT, W-101, 2000.00, 43000.00; CREDIT, W-303, 2000.00, 2000.00} |
| Bola Ade | bola@example.com | 08022222222 | W-202 | NGN | 15000.00 | TXN-901 | TRANSFER | W-101 | W-202 | 5000.00 | SUCCESSFUL | {DEBIT, W-101, 5000.00, 45000.00; CREDIT, W-202, 5000.00, 15000.00} |
| Chi Eze | chi@example.com | 08033333333 | W-303 | NGN | 2000.00 | TXN-902 | TRANSFER | W-101 | W-303 | 2000.00 | SUCCESSFUL | {DEBIT, W-101, 2000.00, 43000.00; CREDIT, W-303, 2000.00, 2000.00} |
| System Clearing | *NULL* | *NULL* | W-999 | NGN | -50000.00 | TXN-801 | DEPOSIT | W-999 | W-101 | 50000.00 | SUCCESSFUL | {DEBIT, W-999, 50000.00, -50000.00; CREDIT, W-101, 50000.00, 50000.00} |

> [!NOTE]
> Tables 2.1 and 3.1 are an **illustrative example with stated opening balances**, used to show repeating groups and partial dependencies. They are not the data loaded into the database.

### Problems with this design:
1. **Repeating groups:** one row holds several transfers, and each transfer holds a list of ledger lines.
2. **Mixed entities:** customer details, wallet balances, transfers and ledger lines are all in the same row.
3. **Anomalies:** adding, changing or deleting one fact means editing these repeated, nested values (Section 5).

---

## 3. Step-by-Step Conversion: 1NF to 3NF

### 3.1 First Normal Form (1NF)

**Rule:** a table is in 1NF if:
1. every column holds a single (atomic) value, with no repeating groups, lists or nested sets; and
2. each row can be identified by a key.

#### From UNF to 1NF:
Remove the repeating groups so that **each row is one ledger entry**. Each row names the wallet affected (`EntryWallet`) and its balance after the entry (`BalanceAfter`).

### Table 3.1: Flattened 1NF Representation (FLATTENED_TRANSACTION_LOG)

| RowID (PK) | TransferRef | EntryType | EntryWallet | WalletOwner | OwnerEmail | OwnerPhone | TransferType | SourceWallet | DestWallet | Amount | BalanceAfter | Status |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | TXN-901 | DEBIT | W-101 | Ada Obi | ada@example.com | 08011111111 | TRANSFER | W-101 | W-202 | 5000.00 | 45000.00 | SUCCESSFUL |
| 2 | TXN-901 | CREDIT | W-202 | Bola Ade | bola@example.com | 08022222222 | TRANSFER | W-101 | W-202 | 5000.00 | 15000.00 | SUCCESSFUL |
| 3 | TXN-902 | DEBIT | W-101 | Ada Obi | ada@example.com | 08011111111 | TRANSFER | W-101 | W-303 | 2000.00 | 43000.00 | SUCCESSFUL |
| 4 | TXN-902 | CREDIT | W-303 | Chi Eze | chi@example.com | 08033333333 | TRANSFER | W-101 | W-303 | 2000.00 | 2000.00 | SUCCESSFUL |

#### Notes on Table 3.1:
- Every value is atomic, and each ledger entry has exactly one row.
- Each `(TransferRef, EntryType)` pair is unique (for example, Row 1 is `(TXN-901, DEBIT)` and Row 2 is `(TXN-901, CREDIT)`).
- The amounts agree with the stated opening balances:
  - Ada Obi (W-101) started with ₦50,000.00. After TXN-901 (₦5,000.00 debit) W-101 held ₦45,000.00; after TXN-902 (₦2,000.00 debit), ₦43,000.00.
  - Bola Ade (W-202) started with ₦10,000.00. After TXN-901 (₦5,000.00 credit), ₦15,000.00.
  - Chi Eze (W-303) started with ₦0.00. After TXN-902 (₦2,000.00 credit), ₦2,000.00.

#### Splitting names:
KoraPay stores `first_name` and `last_name` separately. This is a **design choice, not a 1NF requirement**: a full name such as `"Ada Obi"` is already atomic. The split makes searching, sorting and greetings easier.

---

### 3.2 Second Normal Form (2NF)

**Rule:** a table is in 2NF if:
1. it is in 1NF; and
2. every non-key attribute depends on the **whole** of every candidate key, not just part of a composite key.

#### Surrogate keys do not settle 2NF:
Adding a single-column key such as `RowID` does **not** make a table 2NF. Every candidate key must be checked.

Table 3.1 has a second, composite candidate key:
- `{TransferRef, EntryType}`

#### The partial dependency:
The transfer details depend on `TransferRef` alone, which is only part of that key:

`TransferRef -> {TransferType, SourceWallet, DestWallet, Amount, Status}`

They do not depend on `EntryType`, so this is a **partial dependency**, which breaks 2NF.

*(`EntryWallet -> WalletOwner, OwnerEmail, OwnerPhone` is not a partial dependency, because `EntryWallet` is not part of `{TransferRef, EntryType}`. It is a dependency between non-key columns and is dealt with in the next step.)*

#### Splitting into 2NF tables:
Table 3.1 is split into three tables:

1. **`TRANSACTIONS_2NF`** (one row per transfer):
   - **Key:** `{TransferRef}`
   - **Columns:** `TransferRef`, `TransferType`, `SourceWallet`, `DestWallet`, `Amount`, `Status`.

2. **`LEDGER_LINES_2NF`** (one row per ledger entry):
   - **Key:** `{TransferRef, EntryType}`
   - **Columns:** `TransferRef`, `EntryType`, `EntryWallet`, `BalanceAfter`.
   - Both key columns are needed to know which wallet was affected and its `BalanceAfter`.

3. **`ACCOUNTS_2NF`** (one row per wallet):
   - **Key:** `{EntryWallet}`
   - **Columns:** `EntryWallet`, `WalletOwner`, `OwnerEmail`, `OwnerPhone`.

This removes the partial dependency on `{TransferRef, EntryType}`.

---

### 3.3 Third Normal Form (3NF)

**Rule:** a table is in 3NF if it is in 2NF and, for every non-trivial dependency $X \rightarrow A$, either:
1. $X$ is a **superkey**, or
2. $A$ is a **prime attribute** (part of some candidate key).

Put simply, non-key columns must depend on a key and not on other non-key columns.

#### Separating customers from wallets:
`ACCOUNTS_2NF` holds customer details next to wallet details. Because each customer owns **at most one wallet**, `customer_id` and `wallet_id` determine each other for customer wallets (see [Section 4.2](#42-table-wallets)). So 3NF alone does not force customers and wallets apart.

They are separated for these reasons:
1. **They are different things:** customers are people or businesses with identity and KYC details; wallets are accounts with balances.
2. **Different changes:** profile updates and balance updates are kept apart, while registration can still create both in one transaction.
3. **The clearing wallet has no owner:** the system clearing wallet (`wallet_type = 'SYSTEM_CLEARING'`, `customer_id IS NULL`) would otherwise need dummy customer data or `NULL`s in required columns (`first_name`, `last_name`, `email`, `phone_number`).

Together with `transactions` and `ledger_entries`, this gives the final four tables.

---

## 4. Functional Dependencies and Candidate Keys by Table

### 4.1 Table: `customers`

- **Attributes:** `customer_id`, `first_name`, `last_name`, `email`, `phone_number`, `verification_status`, `created_at`, `updated_at`.
- **Candidate keys:**
  1. `{customer_id}` (primary key)
  2. `{email}`
  3. `{phone_number}`
- **Functional dependencies:**
  - `customer_id -> first_name, last_name, email, phone_number, verification_status, created_at, updated_at`
  - `email -> customer_id, first_name, last_name, phone_number, verification_status, created_at, updated_at`
  - `phone_number -> customer_id, first_name, last_name, email, verification_status, created_at, updated_at`
- **3NF:** every determinant is a candidate key, so `customers` is in 3NF.

---

### 4.2 Table: `wallets`

- **Attributes:** `wallet_id`, `customer_id`, `wallet_number`, `wallet_type`, `currency`, `balance`, `status`, `created_at`, `updated_at`.
- **Candidate keys:**
  1. `{wallet_id}` (primary key)
  2. `{wallet_number}`
- **Why `customer_id` is not a candidate key:**
  - `UNIQUE (customer_id)` ensures a customer has at most one wallet.
  - But a candidate key cannot contain nulls, and the clearing wallet has `customer_id IS NULL`. So `customer_id` is a **conditional unique identifier**: unique among customer wallets only.
- **Functional dependencies:**
  - `wallet_id -> customer_id, wallet_number, wallet_type, currency, balance, status, created_at, updated_at`
  - `wallet_number -> wallet_id, customer_id, wallet_type, currency, balance, status, created_at, updated_at`
- **3NF:** every determinant is a candidate key, so `wallets` is in 3NF. The final `wallets` table holds no customer details, so there is no `wallet_id -> customer_id -> email` chain inside it.
- **Why customers are a separate table** (summary of Section 3.3):
  1. **Different things:** people or businesses versus accounts.
  2. **The clearing wallet:** it has no owner, so a merged table would need dummy customer data or `NULL`s in required columns.
  3. **Future change:** separate wallets would allow, for example, foreign-currency wallets later without changing `customers`.

---

### 4.3 Table: `transactions`

- **Attributes:** `transaction_id`, `reference`, `transaction_type`, `source_wallet_id`, `destination_wallet_id`, `amount`, `status`, `reversal_of_transaction_id`, `description`, `created_at`.
- **Candidate keys:**
  1. `{transaction_id}` (primary key)
  2. `{reference}` (the client's idempotency key)
- **Functional dependencies:**
  - `transaction_id -> reference, transaction_type, source_wallet_id, destination_wallet_id, amount, status, reversal_of_transaction_id, description, created_at`
  - `reference -> transaction_id, transaction_type, source_wallet_id, destination_wallet_id, amount, status, reversal_of_transaction_id, description, created_at`
- **3NF:** both determinants are candidate keys, so `transactions` is in 3NF.

---

### 4.4 Table: `ledger_entries`

- **Attributes:** `ledger_entry_id`, `transaction_id`, `wallet_id`, `entry_type`, `amount`, `balance_after`, `created_at`.
- **Candidate keys:**
  1. `{ledger_entry_id}` (primary key)
  2. `{transaction_id, entry_type}` (enforced by `UNIQUE (transaction_id, entry_type)`)
- **Functional dependencies:**
  - `ledger_entry_id -> transaction_id, wallet_id, entry_type, amount, balance_after, created_at`
  - `{transaction_id, entry_type} -> ledger_entry_id, wallet_id, amount, balance_after, created_at`
- **Deliberate departure from 2NF and 3NF:**
  - Under the intended posting rule, both entries of a successful transaction have the transaction's amount, so `transaction_id -> amount`.
  - `transaction_id` is only part of the key `{transaction_id, entry_type}`, so this is a **partial dependency**.
  - Storing `amount` in `ledger_entries` therefore breaks strict 2NF, and so strict 3NF.
  - **This rule is not enforced by the schema.** The DDL enforces only `amount > 0` and `UNIQUE (transaction_id, entry_type)`; equal amounts depend on the proposed posting logic.
  - **Why keep it:** each entry is self-contained, so statements, audits and balance checks can use `ledger_entries` without joining `transactions`.
  - `ledger_entries` is therefore a **deliberately denormalised ledger**.

---

## 5. Anomalies in the Unnormalised Design

These problems arise in Tables 2.1 and 3.1, and are removed by the final schema.

### 5.1 Insertion Anomaly
- **Problem:** a customer cannot be recorded until they make a transfer.
- **Example:** to register Chi Eze before any transfer, the sheet would need `NULL`s in the transfer columns (`TransferRef`, `Amount`) or a made-up transfer.
- **Normalised design:** registration adds a row to `customers` and a wallet to `wallets` (proposed: in one transaction), with no transaction needed.

### 5.2 Update Anomaly
- **Problem:** a fact stored in many rows must be changed in all of them. If one update is missed, the data disagrees.
- **Example:** Ada Obi's phone number (`08011111111`) appears in rows 1 and 3 of Table 3.1. Changing it means updating both; missing one leaves two different numbers for the same customer.
- **Normalised design:** the phone number is stored once, in `customers`.

### 5.3 Deletion Anomaly
- **Problem:** deleting a transfer can also delete unrelated customer or wallet data.
- **Example:** Chi Eze (W-303) appears only in Row 4 (the CREDIT of `TXN-902`). Deleting `TXN-902`, for instance when clearing out test data, would delete the only record of Chi Eze's details and wallet (`Chi Eze`, `chi@example.com`, `08033333333`, `W-303`).
- **Normalised design:** deleting or rolling back a transaction leaves `customers` and `wallets` untouched.

---

## 6. Stored Derived and Repeated Values

Normalisation discourages storing values that can be calculated from other data. KoraPay Wallet deliberately stores **two derived values and one repeated value**, for speed and auditability.

### 6.1 Cached Balance (`wallets.balance`), derived
- **What it is:** the wallet's total credits minus total debits:
  `balance = sum(CREDIT amounts) - sum(DEBIT amounts)`
- **Why:** checking a balance does not need to add up the whole ledger, and the wallet row can be locked (`SELECT ... FOR UPDATE`) during a transfer.
- **What keeps it correct:** each transfer must update `wallets.balance` and insert the ledger entries **in the same transaction**. A reconciliation query to check this regularly is proposed.

### 6.2 Balance Snapshot (`ledger_entries.balance_after`), derived
- **What it is:** the wallet's balance just after the entry. It is saved only if the transaction commits.
- **Why:** auditors and support staff can see the balance at any point in history without recalculating it.
- **Note:** the schema does **not** prevent these rows from being edited. An append-only ledger needs the proposed role permissions.

### 6.3 Repeated Amount (`ledger_entries.amount`), repeated
- **What it is:** the transaction amount, copied onto both the debit and the credit entry.
- **Why:** statements and reconciliation can run on `ledger_entries` alone, without joining `transactions`.
- **What keeps it correct:** the proposed posting routine must write both entries with exactly `transactions.amount`.

---

## 7. Schema Constraints vs. Proposed Posting Logic

### 7.1 Implemented in the Schema (tested in Portfolio 1)
[`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql`](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P1_02_CreateTables.sql) implements:
- **Foreign keys** with `ON DELETE RESTRICT`, so linked rows cannot be deleted.
- **Uniqueness:**
  - unique emails, phone numbers and wallet numbers;
  - at most one wallet per customer (`UNIQUE (customer_id)`);
  - unique request references (`UNIQUE (reference)`);
  - at most one DEBIT and one CREDIT per transaction (`UNIQUE (transaction_id, entry_type)`).
- **Business rules:**
  - customer wallets need an owner; the clearing wallet must not have one;
  - at most one clearing wallet (`uq_single_system_clearing_wallet`);
  - at most one reversal per transaction (`uq_single_reversal_per_transaction`);
  - allowed values for `verification_status`, `wallet_type`, `currency = 'NGN'`, `status`, `transaction_type` and `entry_type`;
  - customer balances cannot be negative; the clearing wallet can;
  - amounts must be positive (`amount > 0`) in `transactions` and `ledger_entries`;
  - source and destination wallets must differ;
  - a reversal link is required for a `'REVERSAL'` and not allowed otherwise, and a transaction cannot reverse itself.

### 7.2 What the Schema Cannot Enforce
Constraints cannot:
1. require **exactly two** entries per successful transaction (they only limit it to at most two);
2. require the debit and credit amounts to be equal;
3. keep `wallets.balance` equal to the ledger total;
4. stop someone editing ledger entries directly.

### 7.3 Proposed Controls (not implemented in Portfolio 1)
- **One posting routine** (for example a PL/pgSQL function `post_ledger_movement`): locks both wallets in ascending `wallet_id` order, checks statuses and balances, writes both ledger entries and updates both balances in one transaction.
- **Least-privilege permissions:** revoke direct `INSERT`, `UPDATE` and `DELETE` on `ledger_entries`, and direct `UPDATE` on `wallets.balance`, from the application role. Writes go only through the posting function (`SECURITY DEFINER`).
- **Idempotent retries:**
  1. **Claim the reference first:** insert the `'PENDING'` transaction row before moving money.
  2. **Retry with the same reference:** after a timeout or disconnect, the client resends the same reference, not a new one.
  3. **Compare with the stored row:** check `source_wallet_id`, `destination_wallet_id` and `amount`. The `transactions` table has no currency column, so currency is checked through the wallets (both must be `'NGN'`). Any difference is rejected with an error.
  4. **Handle the conflict cleanly:** use `INSERT ... ON CONFLICT (reference) DO NOTHING`, or `ROLLBACK` and then look up the existing row in a new transaction, so nothing runs inside an aborted transaction.
- **Reconciliation:** a regular query comparing each cached balance with its ledger total.

> [!IMPORTANT]
> **Portfolio 1 does not move money.** It implements and tests the schema and its constraints. Posting, locking and the other controls above were proposed for later portfolios.
>
> *Update:* Portfolio 3 later implemented and tested ascending-`wallet_id` locking, a transfer function with idempotent retries, and reconciliation checks. The `SECURITY DEFINER` routine, revoked privileges and reversals were not implemented. See the [Portfolio 3 README](../portfolio-3-transactions-concurrency/README.md).

---

## 8. Summary

| Table | Primary Key | Other Candidate Keys | Normal Form | Main Reason for the Design |
| :--- | :--- | :--- | :---: | :--- |
| **`customers`** | `customer_id` | `{email}`, `{phone_number}` | **3NF** | Customer details stored once; customers can exist without any transaction. |
| **`wallets`** | `wallet_id` | `{wallet_number}` | **3NF** | Accounts kept apart from personal details; allows an ownerless clearing wallet. |
| **`transactions`** | `transaction_id` | `{reference}` (idempotency key) | **3NF** | One row per request, separate from the ledger lines. |
| **`ledger_entries`** | `ledger_entry_id` | `{transaction_id, entry_type}` | **Deliberately denormalised** | Each line carries its own `amount`, so audits and reconciliation need no join. |

### Conclusion
`customers`, `wallets` and `transactions` are in 3NF. `ledger_entries` deliberately repeats `amount` so each entry is self-contained. The schema enforces structure and valid values. Balanced posting, an unchangeable ledger and automatic reconciliation need the proposed posting routine, permissions and checks described above.
