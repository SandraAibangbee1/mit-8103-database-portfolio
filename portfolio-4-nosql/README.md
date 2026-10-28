# Portfolio 4: NoSQL (MongoDB)

- **Student:** Sandra Aibangbee
- **Student ID:** 2026/A/MIT/0301/301897710
- **Course:** MIT 8103 Advanced Database Systems
- **Database:** `korapay_nosql` on MongoDB Atlas (cluster replica set `atlas-mkcu1x-shard-0`, as shown in every screenshot prompt)
- **Collection:** `transaction_notifications`

---

## 1. Purpose

This portfolio stores KoraPay Wallet transaction notifications as MongoDB documents. A notification records whether an EMAIL, SMS or PUSH message was sent for a transfer. Each document embeds its `message` and an `attempts` array of delivery attempts. Delivery is simulated; no message was actually sent.

The full discussion is in [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_NoSQLAnalysis.md](Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_NoSQLAnalysis.md).

## 2. How the work was done

> [!IMPORTANT]
> All experiments were run **interactively** in the mongosh shell inside MongoDB Compass, connected to Atlas. The screenshots are the record of what was run.
>
> The files in `scripts/` were **written afterwards** from the screenshots and the JSON export. **None of them has been run as a file.** Some commands were not fully visible in the screenshots and have been **reconstructed** (see the Status column below).

## 3. Experiments and evidence

All file names start with `Aibangbee_Sandra_2026_A_MIT_0301_301897710_`.

| # | Experiment | Screenshot | Result shown |
|---|---|---|---|
| 1 | Create the collection with `$jsonSchema` validation | P4_01 (top) | Only the final `{ ok: 1 }`; the validator text is not visible |
| 2 | Insert an invalid document (`INVALID-001`, channel `WHATSAPP`) | P4_01 | `MongoServerError: Document failed validation` |
| 3 | Insert P4-N001 as PENDING and read it back | P4_02 | `insertedId` `6adfaf5bab44da5feacbc4c4`; `findOne` shows PENDING, `created_at` 2026-10-26T19:51:55.148Z, `attempts: []` |
| 4 | Mark P4-N001 as SENT with one simulated attempt | P4_03 | `matchedCount: 1`, `modifiedCount: 1`; document shows SENT and one SIMULATED attempt at 19:57:08.159Z. The update command itself is not visible |
| 5 | Copy P4-N001 as P4-DELETE-TEST, delete it, count it | P4_04 | `insertedId` `6adfb174ab44da5feacbc4c5`, `deletedCount: 1`, count `0` |
| 6 | Insert five samples P4-N002 to P4-N006 | P4_05 (top) | Five `insertedIds` `…c4c6` to `…c4ca`; only the end of the command is visible |
| 7 | Count notifications by status | P4_05 (bottom) | FAILED 1, PENDING 2, SENT 3 |
| 8 | Unique index on `notification_id`, then insert a duplicate | P4_07 | `uq_notification_id` created; `getIndexes` shows it as unique; two duplicate inserts both rejected with E11000 |
| 9 | Collection scan vs indexed lookup | P4_08 | Scan: 6 documents examined, 0 keys; index: 1 document, 1 key |

There is no P4_06 screenshot. The index was created in the session shown in P4_07.

## 4. Files

### `scripts/` (written after the session; not run as files)

| File | Type | Status |
|---|---|---|
| `…_P4_01_CreateCollection.js` | Changes data | **Reconstructed**: the validator is written from the recorded rules, not copied |
| `…_P4_02_ValidationRejection.js` | Write attempt (rejected) | Transcribed from P4_01 |
| `…_P4_03_InsertAndRead.js` | Changes data | **Partly reconstructed**: the start of the insert is scrolled out of view in P4_02 |
| `…_P4_04_UpdateStatus.js` | Changes data | **Reconstructed**: P4_03 shows only the result |
| `…_P4_05_DeleteTest.js` | Changes data (net zero) | Transcribed from P4_04, with print wrappers added |
| `…_P4_06_InsertSamples.js` | Changes data | **Reconstructed** from the end of the command in P4_05 and the JSON export |
| `…_P4_07_UniqueIndex.js` | Creates an index | Transcribed from P4_07, with print wrappers added |
| `…_P4_08_StatusAggregation.js` | Read-only | Transcribed from P4_05 |
| `…_P4_09_IndexAccessPath.js` | Read-only | Transcribed from P4_08 |
| `…_P4_10_VerifyCollection.js` | Read-only | **New**: never run in any form |

Scripts 01, 03, 04 and 06 contain guards that stop them if the recorded data already exists. These guards were added when the files were written and have not been tested.

### `output/`

| File | Contents |
|---|---|
| `…_P4_NotificationsExport.json` | Compass export of the 6 final documents, in Extended JSON (`$oid`, `$date`). It matches the screenshots: same ObjectIds, statuses and timestamps, and only P4-N001 has an attempt |

### `screenshots/`

| File | Shows |
|---|---|
| `…_P4_01_ValidationRejected.png` | `{ ok: 1 }` from creating the collection, then the rejected WHATSAPP insert |
| `…_P4_02_NotificationCreatedAndRead.png` | Insert of P4-N001 and `findOne` showing PENDING |
| `…_P4_03_NotificationUpdated.png` | Update result and `findOne` showing SENT with one SIMULATED attempt |
| `…_P4_04_NotificationDeleted.png` | P4-DELETE-TEST insert, delete and count |
| `…_P4_05_StatusAggregation.png` | `insertMany` result and the status counts |
| `…_P4_07_DuplicateRejected.png` | Index creation, `getIndexes` and two E11000 rejections |
| `…_P4_08_IndexComparison.png` | Scan vs index execution statistics |

The five `…_P5_0N_…png` files in this `screenshots/` folder are untracked copies of the Portfolio 5 screenshots. They are not Portfolio 4 evidence.

## 5. Running the scripts (untested)

The scripts have not been run as files, so these steps are untested. To try them against a new, empty `korapay_nosql` database:

```bash
mongosh "mongodb+srv://<cluster>/" --file scripts/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_01_CreateCollection.js
# then P4_02 to P4_07 in order, then the read-only P4_08 to P4_10
```

Do not store or hard-code a database password.

## 6. AI assistance

The mongosh scripts, this README and the analysis were prepared with the help of an AI coding tool (Google Antigravity / Gemini). It structured and documented the scripts and checked them against the saved screenshots and exported JSON. The experiments were run by the student in MongoDB Compass before the scripts were written. The AI did not run any commands against the database and had no access to the connection string or credentials.

Claude later simplified the wording of this README, the analysis and the script headers, labelled which scripts are reconstructed or transcribed, checked the documentation against the screenshots and the JSON export, and renamed the files to the naming standard.
