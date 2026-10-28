// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_02_ValidationRejection.js
// Status:      TRANSCRIBED from P4_01. Written after the interactive session; not run as a file.
// Type:        ATTEMPTS A WRITE (expected to be rejected; no data change)
// Description: Inserts an incomplete document with an invalid channel.
//              Matches the command visible in P4_01.
// Recorded (P4_01): MongoServerError: Document failed validation.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

db.transaction_notifications.insertOne({
  notification_id: "INVALID-001",
  channel: "WHATSAPP"
});
