# Portfolio 5 — Distributed Database and Cloud Deployment

**Course:** MIT 8103 Advanced Database Systems
**Student:** Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
**Platform:** MongoDB Atlas (cloud-managed MongoDB)
**Cluster:** `korapay-cluster`
**Provider / Region:** AWS, Paris (`eu-west-3`)

---

## Purpose

This portfolio examines how the KoraPay notification data from Portfolio 4
operates within a cloud-hosted, replicated MongoDB deployment.  The focus is
on observing and explaining the distributed-systems properties that MongoDB
Atlas provides — replication across a three-node replica set — and discussing
architectural concepts including high availability, consistency, disaster
recovery, and sharding.

> [!IMPORTANT]
> This portfolio is an **observational and analytical** exercise.  No failover,
> recovery, sharding, cross-region replication or performance benchmarking was
> tested.  All claims about distributed behaviour are based on documented
> MongoDB Atlas behaviour, not on experiments conducted in this portfolio.

---

## Observations Summary

| # | Observation | Screenshot | Key detail |
|---|------------|-----------|------------|
| 1 | Atlas cluster overview | P5_01 | `korapay-cluster`, AWS eu-west-3, Replica Set – 3 nodes, Version 8.0.34, Backups Inactive |
| 2 | Cloud database listing | P5_02 | `korapay_nosql` database: 36.86 kB storage, 1 collection, 2 indexes |
| 3 | Cloud notification documents | P5_03 | `transaction_notifications`: 6 documents, 2 indexes, P4-N001 and P4-N002 visible |
| 4 | Replica set members (`db.hello()`) | P5_04 | Replica set `atlas-mkcu1x-shard-0`, primary identified, 3 members listed |
| 5 | Cloud read of P4-N001 | P5_05 | `findOne` returned complete P4-N001 document from the cloud cluster |

---

## File Inventory

### `screenshots/`

| File | Shows |
|------|-------|
| `…_P5_01_AtlasCluster.png` | Atlas Clusters page: `korapay-cluster` on AWS Paris (eu-west-3), Replica Set – 3 nodes, version 8.0.34, Backups Inactive |
| `…_P5_02_CloudDatabase.png` | Data Explorer: `korapay_nosql` (36.86 kB storage, 1.69 kB data, 1 collection, 2 indexes); "Connected to korapay-cluster" |
| `…_P5_03_CloudNotifications.png` | `transaction_notifications` collection: 6 documents displayed with P4-N001 and P4-N002 visible |
| `…_P5_04_ReplicaSetMembers.png` | `db.hello()` output: replica set `atlas-mkcu1x-shard-0`, `isPrimary: true`, primary and 3 members listed |
| `…_P5_05_CloudRead.png` | `findOne({ notification_id: "P4-N001" })` returning the complete document |

All screenshot filenames carry the prefix
`Aibangbee_Sandra_2026_A_MIT_0301_301897710`.

### Analysis Document

See [`distributed-cloud-analysis.md`](./distributed-cloud-analysis.md) for the
full discussion of replication, availability, consistency, disaster recovery,
sharding, and the relationship to the KoraPay system.

---

## What Was and Was Not Done

### Observed (with screenshot evidence)

- The Atlas cluster is live and reachable on AWS eu-west-3
- The cluster runs as a 3-node replica set (confirmed by Atlas UI and `db.hello()`)
- The `korapay_nosql` database and its `transaction_notifications` collection
  with 6 documents are present and queryable from the cloud
- A read-only `findOne` successfully returned P4-N001
- Atlas shows backups as inactive

### Not tested or implemented

- Failover (no node was shut down or failed over)
- Backup and point-in-time recovery
- Sharding (proposed only — see analysis)
- Cross-region replication
- Write-concern or read-concern experiments
- Performance or latency benchmarking
- PostgreSQL-to-MongoDB integration or cross-database referential integrity

---

## AI Assistance Disclosure

The README and analysis document were prepared with the assistance of an AI
coding tool (Google Antigravity / Gemini).  The AI was used to structure the
documents, cross-reference screenshots, and draft explanations of distributed
database concepts.  All observations are drawn from the student's own
screenshots of the live Atlas cluster and mongosh session.  The AI did not
access the Atlas account, the database connection string, or any credentials.
