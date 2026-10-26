// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   Milestone 4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_07_unique_index.js
// Type:        CHANGES SCHEMA (creates an index), then ATTEMPTS a duplicate
//              insert that is expected to be rejected
// Description: Matches the commands visible in P4_07.
// Recorded (P4_07): createIndex returned "uq_notification_id"; getIndexes
//   lists _id_ and uq_notification_id (unique: true); the duplicate insert
//   failed with "E11000 duplicate key error collection:
//   korapay_nosql.transaction_notifications index: uq_notification_id dup key"
//   (the rest of the message is cut off in the screenshot). The duplicate
//   attempt appears twice in P4_07; both were rejected.
// createIndex with the same name and keys is a no-op if it already exists.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

print(db.transaction_notifications.createIndex(
  { notification_id: 1 },
  { unique: true, name: "uq_notification_id" }
));

printjson(db.transaction_notifications.getIndexes());

// Expected to fail with E11000.
var duplicateTest = db.transaction_notifications.findOne({
  notification_id: "P4-N001"
});
delete duplicateTest._id;
db.transaction_notifications.insertOne(duplicateTest);
