// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_P4_04_UpdateStatus.js
// Status:      RECONSTRUCTED. Written after the interactive Compass session; not run as a file.
// Type:        CHANGES DATA (update), then read
// Description: Marks P4-N001 as SENT and appends one SIMULATED delivery
//              attempt. No message is actually sent.
//
// RECONSTRUCTED: P4_03 shows only the result (matchedCount 1, modifiedCount
// 1) and the document afterwards, not the update command itself. The update
// below produces the recorded document.
// Recorded (P4_03): status 'SENT'; attempts [{ attempted_at
//   2026-10-26T19:57:08.159Z, outcome 'SENT', provider 'SIMULATED' }].
// The equivalent commands were run interactively. Guard: stops unless P4-N001 is PENDING.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

if (db.transaction_notifications.countDocuments({ notification_id: "P4-N001", status: "PENDING" }) !== 1) {
  throw new Error("P4-N001 is not PENDING (already updated?). Nothing was changed.");
}

printjson(db.transaction_notifications.updateOne(
  { notification_id: "P4-N001" },
  {
    $set: { status: "SENT" },
    $push: {
      attempts: {
        attempted_at: new Date(),
        outcome: "SENT",
        provider: "SIMULATED"
      }
    }
  }
));

printjson(db.transaction_notifications.findOne({ notification_id: "P4-N001" }));
