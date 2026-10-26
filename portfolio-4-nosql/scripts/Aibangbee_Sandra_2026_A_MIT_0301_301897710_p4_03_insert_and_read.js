// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   Milestone 4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_03_insert_and_read.js
// Type:        CHANGES DATA (create), then read
// Description: Inserts notification P4-N001 as PENDING and reads it back.
//              The visible part of P4_02 matches the fields below; the first
//              lines of the insert are scrolled out of view.
// Recorded (P4_02): insertedId 6adfaf5bab44da5feacbc4c4; findOne shows
//              status 'PENDING', created_at 2026-10-26T19:51:55.148Z,
//              attempts [].
// Already run in the recorded database. Stops if P4-N001 exists.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

if (db.transaction_notifications.countDocuments({ notification_id: "P4-N001" }) > 0) {
  throw new Error("P4-N001 already exists. Nothing was changed.");
}

db.transaction_notifications.insertOne({
  notification_id: "P4-N001",
  transaction_reference: "P3L-RETRY-COMMIT-001",
  wallet_number: "P3LW000001",
  channel: "EMAIL",
  status: "PENDING",
  message: {
    subject: "Transfer successful",
    body: "Your NGN 1.00 transfer was successful."
  },
  created_at: new Date(),
  attempts: []
});

printjson(db.transaction_notifications.findOne({ notification_id: "P4-N001" }));
