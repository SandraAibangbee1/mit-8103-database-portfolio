// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   Milestone 4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_06_insert_samples.js
// Type:        CHANGES DATA (create five sample notifications)
// Description: Inserts P4-N002 ... P4-N006 for the status aggregation.
//              Status values are set directly; no delivery is attempted, so
//              attempts stays empty even for SENT and FAILED.
//
// RECONSTRUCTED: P4_05 shows only the end of this command
// ("created_at: new Date(), attempts: [] }))" and ")"), which indicates an
// insertMany over a mapped array. The values below match the exported JSON.
// Recorded (P4_05): five insertedIds 6adfb1e8ab44da5feacbc4c6 ... c4ca.
// Already run in the recorded database. Stops if any sample ID exists.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

var samples = [
  ["P4-N002", "SMS",   "SENT"],
  ["P4-N003", "PUSH",  "PENDING"],
  ["P4-N004", "EMAIL", "FAILED"],
  ["P4-N005", "SMS",   "PENDING"],
  ["P4-N006", "PUSH",  "SENT"]
];

if (db.transaction_notifications.countDocuments({
      notification_id: { $in: samples.map(function (s) { return s[0]; }) }
    }) > 0) {
  throw new Error("A sample notification already exists. Nothing was changed.");
}

printjson(db.transaction_notifications.insertMany(
  samples.map(function (s) {
    return {
      notification_id: s[0],
      transaction_reference: "P3L-RETRY-ROLLBACK-001",
      wallet_number: "P3LW000002",
      channel: s[1],
      status: s[2],
      message: { body: "Sample KoraPay transfer notification" },
      created_at: new Date(),
      attempts: []
    };
  })
));
