// ============================================================================
// Course:      MIT 8103 Advanced Database Systems
// Student:     Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
// Portfolio:   Milestone 4 — NoSQL (MongoDB)
// File:        Aibangbee_Sandra_2026_A_MIT_0301_301897710_p4_01_create_collection.js
// Type:        CHANGES DATA (creates the collection and its validator)
// Description: Creates korapay_nosql.transaction_notifications with strict
//              $jsonSchema validation.
//
// RECONSTRUCTED: P4_01 shows only the final "{ ok: 1 }" of this command, not
// the validator text. The schema below is written from the recorded rules:
//   required: notification_id, transaction_reference, wallet_number,
//             channel, status, message, created_at
//   strings:  notification_id, transaction_reference, wallet_number
//   channel:  EMAIL | SMS | PUSH        status: PENDING | SENT | FAILED
//   message:  object                    created_at: date
//   attempts: optional array
//
// Already run in the recorded database. Stops if the collection exists.
// ============================================================================

db = db.getSiblingDB("korapay_nosql");

if (db.getCollectionNames().includes("transaction_notifications")) {
  throw new Error("transaction_notifications already exists. Nothing was changed.");
}

db.createCollection("transaction_notifications", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "notification_id",
        "transaction_reference",
        "wallet_number",
        "channel",
        "status",
        "message",
        "created_at"
      ],
      properties: {
        notification_id:       { bsonType: "string" },
        transaction_reference: { bsonType: "string" },
        wallet_number:         { bsonType: "string" },
        channel:               { enum: ["EMAIL", "SMS", "PUSH"] },
        status:                { enum: ["PENDING", "SENT", "FAILED"] },
        message:               { bsonType: "object" },
        created_at:            { bsonType: "date" },
        attempts:              { bsonType: "array" }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});
