# Portfolio 4 — NoSQL (MongoDB)

**Course:** MIT 8103 Advanced Database Systems
**Student:** Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
**Database:** `korapay_nosql` (MongoDB Atlas)
**Collection:** `transaction_notifications`

---

## Purpose

This portfolio demonstrates a document-oriented extension to the KoraPay Wallet
case study.  Transaction notifications — records that track whether an EMAIL,
SMS or PUSH message has been sent for a completed transfer — are modelled as
MongoDB documents with embedded `message` and `attempts` sub-structures.

The experiments cover:

| # | Experiment | Script(s) | Screenshot(s) |
|---|-----------|-----------|---------------|
| 1 | Collection creation with strict JSON Schema validation | `_p4_01_create_collection.js` | P4_01 (tail end showing `{ ok: 1 }` and subsequent validation rejection) |
| 2 | Validation rejection of an incomplete / invalid document | `_p4_02_validation_rejection.js` | P4_01 |
| 3 | Insert and read P4-N001 (Create + Read) | `_p4_03_insert_and_read.js` | P4_02 |
| 4 | Update P4-N001 to SENT with a simulated delivery attempt | `_p4_04_update_status.js` | P4_03 |
| 5 | Create and delete P4-DELETE-TEST (Delete) | `_p4_05_delete_test.js` | P4_04 |
| 6 | Insert five sample notifications P4-N002 … P4-N006 | `_p4_06_insert_samples.js` | P4_05 (top half: insertMany result) |
| 7 | Aggregation by status | `_p4_08_status_aggregation.js` (read-only) | P4_05 (bottom half: aggregation output) |
| 8 | Unique index + duplicate rejection | `_p4_07_unique_index.js` | P4_07 |
| 9 | Collection scan vs. indexed lookup (access-path demo) | `_p4_09_index_access_path.js` (read-only) | P4_08 |
| — | Final verification of recorded state | `_p4_10_verify_collection.js` (read-only) | *(no screenshot — script not yet run)* |

All script filenames carry the prefix
`Aibangbee_Sandra_2026_A_MIT_0301_301897710`.

---

## File Inventory

### `scripts/`

| File | Type | Safe to re-run? |
|------|------|-----------------|
| `…_p4_01_create_collection.js` | **CHANGES DATA** — creates collection + validator | No (errors if collection exists) |
| `…_p4_02_validation_rejection.js` | **ATTEMPTS A WRITE** (expected rejection) | Yes (always rejected) |
| `…_p4_03_insert_and_read.js` | **CHANGES DATA** — inserts P4-N001 | No (guard: stops if P4-N001 exists) |
| `…_p4_04_update_status.js` | **CHANGES DATA** — updates P4-N001 | No (guard: stops unless PENDING) |
| `…_p4_05_delete_test.js` | **CHANGES DATA** — insert then delete | Net-neutral but creates a temporary document |
| `…_p4_06_insert_samples.js` | **CHANGES DATA** — inserts P4-N002 … N006 | No (guard: stops if any sample exists) |
| `…_p4_07_unique_index.js` | **CHANGES SCHEMA** — creates index; attempts duplicate | Idempotent for the index; duplicate always fails |
| `…_p4_08_status_aggregation.js` | **READ-ONLY** | Yes |
| `…_p4_09_index_access_path.js` | **READ-ONLY** | Yes |
| `…_p4_10_verify_collection.js` | **READ-ONLY** | Yes |

### `output/`

| File | Contents |
|------|----------|
| `…_p4_notifications.json` | MongoDB Compass export of all 6 documents in Extended JSON format (`$oid`, `$date`) |

### `screenshots/`

| File | Experiment |
|------|-----------|
| `…_P4_01_ValidationRejected.png` | Collection creation result (`{ ok: 1 }`) and validation rejection |
| `…_P4_02_NotificationCreatedAndRead.png` | P4-N001 insertOne result and findOne showing PENDING |
| `…_P4_03_NotificationUpdated.png` | updateOne result (matchedCount 1, modifiedCount 1) and findOne showing SENT with one attempt |
| `…_P4_04_NotificationDeleted.png` | P4-DELETE-TEST insert, deleteOne (deletedCount 1) and countDocuments = 0 |
| `…_P4_05_StatusAggregation.png` | insertMany of 5 samples and aggregation result (FAILED 1, PENDING 2, SENT 3) |
| `…_P4_07_DuplicateRejected.png` | createIndex, getIndexes, and two E11000 duplicate-key rejections |
| `…_P4_08_IndexComparison.png` | Collection scan vs. indexed lookup with execution stats |

> [!WARNING]
> **Missing screenshot:** There is no `P4_06` screenshot.  Index creation
> evidence is captured within `P4_07_DuplicateRejected.png` (which shows
> `createIndex`, `getIndexes`, and the E11000 errors).

---

## Analysis Document

See [`nosql-analysis.md`](./nosql-analysis.md) for the full discussion of:

- Document model design (embedded `message` and `attempts`)
- Validation, CRUD operations, aggregation and indexing
- Observed results with screenshot cross-references
- Why notification metadata suits a document database alongside PostgreSQL
- Limitations, caveats and reproduction instructions

---

## Reproduction Instructions

### Prerequisites

- MongoDB 6.0+ (or MongoDB Atlas M0+) with `mongosh` available
- The database `korapay_nosql` must not already contain
  `transaction_notifications` if you want to run from scratch

### Run the mutating scripts (in order)

```bash
mongosh "mongodb+srv://<cluster>/<dbname>" \
  --file scripts/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_01_create_collection.js
# ... repeat for _p4_02 through _p4_07 in order
```

> [!CAUTION]
> Scripts 01–07 change data or schema.  They include guards that refuse to run
> if the expected prior state is not found, but you should review each script
> before execution.  **Do not store or hard-code your database password.**

### Run the read-only verification scripts (any order)

```bash
mongosh "mongodb+srv://<cluster>/<dbname>" \
  --file scripts/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_08_status_aggregation.js
mongosh "mongodb+srv://<cluster>/<dbname>" \
  --file scripts/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_09_index_access_path.js
mongosh "mongodb+srv://<cluster>/<dbname>" \
  --file scripts/Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_10_verify_collection.js
```

---

## AI Assistance Disclosure

The mongosh scripts, README and analysis document were prepared with the
assistance of an AI coding tool (Google Antigravity / Gemini).  The AI was used
to structure, document and verify the scripts against the saved screenshots and
exported JSON.  All experiments were executed by the student in MongoDB Compass
prior to script generation.  The AI did not execute any commands against the
database and had no access to the database connection string or credentials.
