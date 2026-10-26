# Portfolio 4 — NoSQL Analysis: Transaction Notifications in MongoDB

**Course:** MIT 8103 Advanced Database Systems
**Student:** Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
**Database:** `korapay_nosql` · **Collection:** `transaction_notifications`

---

## 1  Document Model Design

### 1.1  Why a Document Store?

The KoraPay Wallet relational schema (Portfolios 1–3) manages customers,
wallets, transactions and ledger entries in PostgreSQL.  Transaction
*notifications* — the records of whether an email, SMS or push message was
dispatched for a given transfer — have different access patterns:

| Concern | Relational (PostgreSQL) | Document (MongoDB) |
|---------|------------------------|--------------------|
| Schema rigidity | Strict column types and foreign keys | Flexible per-document structure with optional validation |
| Nested data | Requires JOIN or separate tables | Embedded sub-documents and arrays |
| Read pattern | Joins across normalised tables | Single-document reads; no joins needed |
| Write pattern | Row-level INSERT/UPDATE | Atomic document-level updates with `$push` |
| Delivery audit trail | Separate child table or JSONB column | Embedded `attempts` array grows with each retry |

Notification metadata is *self-contained*: a single document holds the
notification ID, the channel, the current status, the message content, and the
full history of delivery attempts.  This maps naturally to a document model
where each notification is one JSON object.

### 1.2  Document Structure

```json
{
  "_id":                    ObjectId("…"),
  "notification_id":        "P4-N001",
  "transaction_reference":  "P3L-RETRY-COMMIT-001",
  "wallet_number":          "P3LW000001",
  "channel":                "EMAIL",
  "status":                 "SENT",
  "message": {
    "subject": "Transfer successful",
    "body":    "Your NGN 1.00 transfer was successful."
  },
  "created_at":             ISODate("2026-10-26T19:51:55.148Z"),
  "attempts": [
    {
      "attempted_at": ISODate("2026-10-26T19:57:08.159Z"),
      "outcome":      "SENT",
      "provider":     "SIMULATED"
    }
  ]
}
```

**Embedded `message`:** The message body (and optional subject for emails) is
stored as a nested object rather than a separate collection.  Notifications are
always read together with their message content, so embedding avoids a lookup.

**Embedded `attempts` array:** Each delivery attempt is appended to the array
with `$push`.  This provides a built-in audit trail without a separate child
table.  The array is expected to remain small (a handful of retries at most).

---

## 2  Schema Validation

The collection was created with `validationLevel: "strict"` and
`validationAction: "error"` using a `$jsonSchema` validator:

```javascript
db.createCollection("transaction_notifications", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "notification_id", "transaction_reference", "wallet_number",
        "channel", "status", "message", "created_at"
      ],
      properties: {
        notification_id:       { bsonType: "string" },
        transaction_reference: { bsonType: "string" },
        wallet_number:         { bsonType: "string" },
        channel:               { enum: ["EMAIL", "SMS", "PUSH"] },
        status:                { enum: ["PENDING", "SENT", "FAILED"] },
        message:               { bsonType: "object" },
        created_at:            { bsonType: "date" },
        attempts:              { bsonType: "array" }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});
```

### 2.1  Validation Rejection Test

An incomplete document with an invalid channel was rejected:

```javascript
db.transaction_notifications.insertOne({
  notification_id: "INVALID-001",
  channel: "WHATSAPP"         // not in enum; also missing required fields
});
// → MongoServerError: Document failed validation
```

**Evidence:** Screenshot
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_01_ValidationRejected.png`
shows the `{ ok: 1 }` result of `createCollection` followed by the
`MongoServerError: Document failed validation` error for the WHATSAPP insert.

The document was rejected for two reasons: (1) `channel: "WHATSAPP"` violates
the `enum` constraint, and (2) required fields `transaction_reference`,
`wallet_number`, `status`, `message` and `created_at` are missing.

---

## 3  CRUD Operations

### 3.1  Create (Insert) and Read — P4-N001

**Script:** `_p4_03_insert_and_read.js` (CHANGES DATA)

```javascript
db.transaction_notifications.insertOne({
  notification_id:       "P4-N001",
  transaction_reference: "P3L-RETRY-COMMIT-001",
  wallet_number:         "P3LW000001",
  channel:               "EMAIL",
  status:                "PENDING",
  message: {
    subject: "Transfer successful",
    body:    "Your NGN 1.00 transfer was successful."
  },
  created_at: new Date(),
  attempts:   []
});

db.transaction_notifications.findOne({ notification_id: "P4-N001" });
```

**Observed result (P4_02 screenshot):**

- `insertedId`: `ObjectId('6adfaf5bab44da5feacbc4c4')`
- `findOne` returned the document with `status: 'PENDING'`,
  `created_at: ISODate('2026-10-26T19:51:55.148Z')`, `attempts: []`
- `message.subject`: `'Transfer successful'`
- `message.body`: `'Your NGN 1.00 transfer was successful.'`

**Evidence:** Screenshot
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_02_NotificationCreatedAndRead.png`

### 3.2  Update — Mark P4-N001 as SENT

**Script:** `_p4_04_update_status.js` (CHANGES DATA)

```javascript
db.transaction_notifications.updateOne(
  { notification_id: "P4-N001" },
  {
    $set:  { status: "SENT" },
    $push: {
      attempts: {
        attempted_at: new Date(),
        outcome:      "SENT",
        provider:     "SIMULATED"
      }
    }
  }
);
```

**Observed result (P4_03 screenshot):**

- `matchedCount: 1`, `modifiedCount: 1`
- `findOne` now shows `status: 'SENT'`
- `attempts` array contains one element:
  - `attempted_at: ISODate('2026-10-26T19:57:08.159Z')`
  - `outcome: 'SENT'`
  - `provider: 'SIMULATED'`

**Evidence:** Screenshot
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_03_NotificationUpdated.png`

> [!NOTE]
> Delivery is **simulated**.  The `provider: 'SIMULATED'` field explicitly marks
> that no email, SMS or push notification was actually dispatched.

### 3.3  Delete — P4-DELETE-TEST

**Script:** `_p4_05_delete_test.js` (CHANGES DATA)

The test copies P4-N001 as P4-DELETE-TEST, deletes it, then counts the
remaining matching documents.

**Observed result (P4_04 screenshot):**

- `insertedId`: `ObjectId('6adfb174ab44da5feacbc4c5')`
- `deletedCount: 1`
- `countDocuments({ notification_id: "P4-DELETE-TEST" })` → `0`

**Evidence:** Screenshot
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_04_NotificationDeleted.png`

---

## 4  Sample Data and Aggregation

### 4.1  Bulk Insert — P4-N002 through P4-N006

**Script:** `_p4_06_insert_samples.js` (CHANGES DATA)

Five sample notifications were inserted with `insertMany`:

| notification_id | channel | status  |
|----------------|---------|---------|
| P4-N002        | SMS     | SENT    |
| P4-N003        | PUSH    | PENDING |
| P4-N004        | EMAIL   | FAILED  |
| P4-N005        | SMS     | PENDING |
| P4-N006        | PUSH    | SENT    |

All five use `transaction_reference: "P3L-RETRY-ROLLBACK-001"`,
`wallet_number: "P3LW000002"`, and
`message.body: "Sample KoraPay transfer notification"`.  Their `attempts`
arrays are empty because status values were set directly without simulated
delivery.

**Observed result (P4_05 screenshot, upper portion):**

- `acknowledged: true`
- Five `insertedIds`: `6adfb1e8ab44da5feacbc4c6` through `…c4ca`

### 4.2  Aggregation — Count by Status

**Script:** `_p4_08_status_aggregation.js` (READ-ONLY)

```javascript
db.transaction_notifications.aggregate([
  { $group: { _id: "$status", total: { $sum: 1 } } },
  { $sort:  { _id: 1 } }
]).toArray();
```

**Observed result (P4_05 screenshot, lower portion):**

| Status  | Count |
|---------|-------|
| FAILED  |     1 |
| PENDING |     2 |
| SENT    |     3 |

The counts match the expected distribution: P4-N001 (SENT) + P4-N002 (SENT) +
P4-N006 (SENT) = 3 SENT; P4-N003 (PENDING) + P4-N005 (PENDING) = 2 PENDING;
P4-N004 (FAILED) = 1 FAILED.

**Evidence:** Screenshot
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_05_StatusAggregation.png`

---

## 5  Indexing

### 5.1  Unique Index on `notification_id`

**Script:** `_p4_07_unique_index.js` (CHANGES SCHEMA)

```javascript
db.transaction_notifications.createIndex(
  { notification_id: 1 },
  { unique: true, name: "uq_notification_id" }
);
```

**Observed result (P4_07 screenshot):**

- `createIndex` returned `"uq_notification_id"`
- `getIndexes()` shows two indexes:
  1. `_id_` (default)
  2. `uq_notification_id` with `key: { notification_id: 1 }` and `unique: true`
- Two duplicate-insert attempts of P4-N001 both failed with:
  `MongoServerError: E11000 duplicate key error collection: korapay_nosql.transaction_notifications index: uq_notification_id dup key`

**Evidence:** Screenshot
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_07_DuplicateRejected.png`

### 5.2  Access-Path Comparison: Collection Scan vs. Index Lookup

**Script:** `_p4_09_index_access_path.js` (READ-ONLY)

Both queries search for `{ notification_id: "P4-N001" }`.  The first is forced
to scan with `hint({ $natural: 1 })`, the second uses
`hint("uq_notification_id")`.

**Observed result (P4_08 screenshot):**

| Metric | Collection Scan | Indexed Lookup |
|--------|----------------|----------------|
| Documents returned | 1 | 1 |
| Documents examined | 6 | 1 |
| Keys examined | 0 | 1 |

The collection scan examined all 6 documents to find the one match.  The
indexed lookup examined 1 key entry and 1 document.

> [!IMPORTANT]
> This is an **access-path demonstration**, not a measured speedup.  With only
> 6 documents, timing differences are negligible.  The value of the comparison
> is that it shows the *mechanism*: without the index MongoDB performs a full
> collection scan, while with the index it uses a targeted B-tree lookup.

**Evidence:** Screenshot
`Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_08_IndexComparison.png`

---

## 6  Exported Data

The file
[`output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_notifications.json`](./output/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_notifications.json)
is a MongoDB Compass JSON export of all 6 documents in the final collection
state.

**Format verification:** The export uses **MongoDB Extended JSON (v2)** notation:

- `_id` values are stored as `{ "$oid": "6adfaf5bab44da5feacbc4c4" }` rather
  than bare hex strings, preserving the ObjectId type.
- `created_at` and `attempted_at` values are stored as
  `{ "$date": "2026-10-26T19:51:55.148Z" }` rather than plain ISO strings,
  preserving the BSON Date type.

This means the export can be re-imported with `mongoimport` and all types will
round-trip correctly.

---

## 7  Architectural Rationale: Document Store Alongside PostgreSQL

### 7.1  Why Notifications Suit a Document Database

Notifications are *supplementary, self-contained records* whose primary access
pattern is *write-once, read-by-notification-id*.  They differ from the core
financial data in several ways:

1. **No cross-document joins required.**  A notification is always read as a
   single unit — the message content and the delivery attempts travel with it.
   There is no need to join against a separate `attempts` table.

2. **Variable structure.**  An EMAIL notification may have a `subject` field
   that an SMS notification lacks.  Document stores handle this naturally
   without nullable columns or wide sparse tables.

3. **Append-heavy audit trail.**  Each delivery retry appends to the `attempts`
   array.  MongoDB's `$push` operator handles this atomically within a single
   document update, without a child-table INSERT + parent-table UPDATE round
   trip.

4. **Decoupled lifecycle.**  Notifications can be retained, archived or purged
   independently of the core transaction ledger.

### 7.2  What Remains in PostgreSQL

The core financial entities — customers, wallets, transactions, and ledger
entries — remain in PostgreSQL because they require:

- Foreign-key referential integrity across tables
- Multi-row ACID transactions (debit + credit must commit atomically)
- Complex analytical queries with joins and window functions
- The concurrency controls demonstrated in Portfolio 3

### 7.3  Integration Caveat

> [!WARNING]
> **PostgreSQL integration and foreign-key enforcement between the relational
> schema and this MongoDB collection are not implemented.**
>
> The `transaction_reference` and `wallet_number` fields in each notification
> document are plain strings that match identifiers used in the PostgreSQL
> schema, but there is no cross-database referential integrity constraint
> enforcing their validity.  In a production system, an application-level
> service would be responsible for ensuring that notifications are only created
> for valid, committed transactions.

---

## 8  Limitations and Caveats

1. **Simulated delivery.**  No actual email, SMS or push notification was sent.
   The `provider: "SIMULATED"` field in the attempts array is a marker, not a
   real provider response.

2. **Small dataset.**  Only 6 documents exist.  The access-path comparison
   shows the mechanism, not production-scale performance.

3. **No cross-database referential integrity.**  See Section 7.3 above.

4. **No application layer.**  The experiments were run interactively in the
   MongoDB Compass shell (mongosh).  There is no API server or message queue.

5. **Reconstructed scripts.**  Several scripts were reconstructed from
   screenshots and exported data because the Compass shell session was not
   recorded as a script file.  The screenshots are the primary evidence.

6. **Missing screenshot P4_06.**  There is no separate P4_06 screenshot for
   index creation.  The index creation command and its result are visible in
   screenshot P4_07 (`DuplicateRejected`).

---

## 9  Screenshot Evidence Index

| Screenshot | Shows |
|-----------|-------|
| `…_P4_01_ValidationRejected.png` | `{ ok: 1 }` from `createCollection`; `MongoServerError: Document failed validation` for the WHATSAPP insert |
| `…_P4_02_NotificationCreatedAndRead.png` | `insertOne` result with `insertedId`; `findOne` showing P4-N001 as PENDING with `created_at` and empty `attempts` |
| `…_P4_03_NotificationUpdated.png` | `updateOne` result (matched 1, modified 1); `findOne` showing SENT status and one SIMULATED attempt |
| `…_P4_04_NotificationDeleted.png` | P4-DELETE-TEST insert, `deleteOne` (deletedCount 1), `countDocuments` = 0 |
| `…_P4_05_StatusAggregation.png` | `insertMany` of 5 samples (5 insertedIds); aggregation output: FAILED 1, PENDING 2, SENT 3 |
| `…_P4_07_DuplicateRejected.png` | `createIndex` → `"uq_notification_id"`; `getIndexes` listing `_id_` and `uq_notification_id` (unique: true); two `E11000` duplicate-key rejections |
| `…_P4_08_IndexComparison.png` | Collection scan (6 docs examined, 0 keys) vs. indexed lookup (1 doc examined, 1 key) |

> [!WARNING]
> **No P4_06 screenshot exists.**  Index creation evidence is in P4_07.
> **No screenshot exists for script `_p4_10_verify_collection.js`** — this
> script has not been run yet.

---

## 10  AI Assistance Disclosure

The mongosh scripts, this analysis document and the Portfolio 4 README were
prepared with the assistance of an AI coding tool (Google Antigravity / Gemini).
The AI was used to:

- Structure and format the script headers, guards and comments
- Cross-reference screenshots and exported JSON to verify data consistency
- Draft the analysis narrative and evidence tables

All MongoDB experiments were executed by the student in the MongoDB Compass
shell prior to script generation.  The AI did not execute any commands against
the database, did not have access to the connection string or credentials, and
did not invent any results, timestamps or screenshots.  All observed values
(ObjectIds, ISODates, counts, error messages) are taken from the saved
screenshots and exported JSON.
