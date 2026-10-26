// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   Milestone 4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_05_delete_test.js
// Type:        CHANGES DATA (create, then delete the same test document)
// Description: Copies P4-N001 as P4-DELETE-TEST, deletes it and counts it.
//              Matches the commands visible in P4_04.
// Recorded (P4_04): insertedId 6adfb174ab44da5feacbc4c5; deletedCount 1;
//              countDocuments({ notification_id: "P4-DELETE-TEST" }) = 0.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

var temporaryNotification = db.transaction_notifications.findOne({
  notification_id: "P4-N001"
});
delete temporaryNotification._id;
temporaryNotification.notification_id = "P4-DELETE-TEST";
printjson(db.transaction_notifications.insertOne(temporaryNotification));

printjson(db.transaction_notifications.deleteOne({
  notification_id: "P4-DELETE-TEST"
}));

print(db.transaction_notifications.countDocuments({
  notification_id: "P4-DELETE-TEST"
}));
