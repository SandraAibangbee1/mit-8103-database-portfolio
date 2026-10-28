// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_09_IndexAccessPath.js
// Status:      TRANSCRIBED from P4_08. Not run as a file.
// Type:        READ-ONLY
// Description: Compares a forced collection scan with a forced lookup on
//              uq_notification_id for the same query. Matches P4_08.
//              An access-path demonstration on 6 documents, not a timing test.
// Recorded (P4_08):
//   collection_scan: returned 1, documents_examined 6, keys_examined 0
//   indexed_lookup:  returned 1, documents_examined 1, keys_examined 1
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

var scan = db.transaction_notifications
  .find({ notification_id: "P4-N001" })
  .hint({ $natural: 1 })
  .explain("executionStats");

var indexed = db.transaction_notifications
  .find({ notification_id: "P4-N001" })
  .hint("uq_notification_id")
  .explain("executionStats");

printjson({
  collection_scan: {
    returned: scan.executionStats.nReturned,
    documents_examined: scan.executionStats.totalDocsExamined,
    keys_examined: scan.executionStats.totalKeysExamined
  },
  indexed_lookup: {
    returned: indexed.executionStats.nReturned,
    documents_examined: indexed.executionStats.totalDocsExamined,
    keys_examined: indexed.executionStats.totalKeysExamined
  }
});
