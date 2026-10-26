// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   Milestone 4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_08_status_aggregation.js
// Type:        READ-ONLY
// Description: Counts notifications by status. Matches P4_05.
// Recorded (P4_05): FAILED 1, PENDING 2, SENT 3.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

printjson(db.transaction_notifications.aggregate([
  {
    $group: {
      _id: "$status",
      total: { $sum: 1 }
    }
  },
  { $sort: { _id: 1 } }
]).toArray());
