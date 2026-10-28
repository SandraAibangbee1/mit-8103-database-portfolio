// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_10_VerifyCollection.js
// Status:      NEW. Written afterwards; never run in any form. No screenshot or output exists.
// Type:        READ-ONLY
// Description: Final verification of the recorded state. Prints one row per
//              check with observed, expected and pass.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

var coll = db.transaction_notifications;
var info = db.getCollectionInfos({ name: "transaction_notifications" })[0] || {};
var options = info.options || {};
var uniqueIndex = coll.getIndexes().filter(function (i) {
  return i.name === "uq_notification_id";
})[0];
var n001 = coll.findOne({ notification_id: "P4-N001" }) || {};

var checks = [
  ["Collection has a $jsonSchema validator",
    !!(options.validator && options.validator.$jsonSchema), true],
  ["validationLevel", options.validationLevel, "strict"],
  ["validationAction", options.validationAction, "error"],
  ["Total documents", coll.countDocuments({}), 6],
  ["P4-DELETE-TEST documents", coll.countDocuments({ notification_id: "P4-DELETE-TEST" }), 0],
  ["INVALID-001 documents", coll.countDocuments({ notification_id: "INVALID-001" }), 0],
  ["P4-N001 status", n001.status, "SENT"],
  ["P4-N001 attempts", (n001.attempts || []).length, 1],
  ["P4-N001 attempt provider", ((n001.attempts || [])[0] || {}).provider, "SIMULATED"],
  ["SENT", coll.countDocuments({ status: "SENT" }), 3],
  ["PENDING", coll.countDocuments({ status: "PENDING" }), 2],
  ["FAILED", coll.countDocuments({ status: "FAILED" }), 1],
  ["uq_notification_id is unique", !!(uniqueIndex && uniqueIndex.unique), true]
];

checks.forEach(function (c, i) {
  printjson({ check: i + 1, name: c[0], observed: c[1], expected: c[2], pass: c[1] === c[2] });
});
