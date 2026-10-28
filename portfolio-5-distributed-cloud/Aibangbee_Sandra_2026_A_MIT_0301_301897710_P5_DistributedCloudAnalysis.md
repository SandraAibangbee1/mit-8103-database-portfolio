# Portfolio 5 — Distributed Database and Cloud Analysis

**Course:** MIT 8103 Advanced Database Systems
**Student:** Sandra Aibangbee (Student ID: 2026/A/MIT/0301/301897710)
**Cluster:** `korapay-cluster` · **Provider:** AWS · **Region:** Paris (`eu-west-3`)

This analysis covers two separate pieces of work:

- **MongoDB Atlas (Sections 1–6):** observations of the cloud cluster that holds the Portfolio 4 data, plus documented MongoDB behaviour.
- **Local PostgreSQL replication (Section 7):** a primary and one standby run in Docker, with replication checked.

Failover, recovery, sharding and read/write-concern settings were **not tested** in either part. Where a section explains them, it relies on documentation.

---

## 1  Cloud Deployment Overview

### 1.1  Observed Cluster Configuration

The KoraPay notification data created in Portfolio 4 is hosted on **MongoDB
Atlas**, MongoDB's fully managed cloud database service.  The cluster
configuration was observed in the Atlas web console and the mongosh shell:

| Property | Observed value | Source |
|----------|---------------|--------|
| Cluster name | `korapay-cluster` | P5_01 |
| Cloud provider | AWS | P5_01 |
| Region | Paris (`eu-west-3`) | P5_01 |
| Cluster type | Replica Set – 3 nodes | P5_01 |
| MongoDB version | 8.0.34 | P5_01 |
| Replica set name | `atlas-mkcu1x-shard-0` | P5_04 |
| Primary node | `ac-mq2siev-shard-00-01.mqgqgau.mongodb.net:27017` | P5_04 |
| Member count | 3 (`…shard-00-00`, `…shard-00-01`, `…shard-00-02`) | P5_04 |
| Database | `korapay_nosql` | P5_02 |
| Collection | `transaction_notifications` | P5_03 |
| Document count | 6 | P5_03 |
| Index count | 2 (`_id_` and `uq_notification_id`) | P5_03 |
| Storage size | 36.86 kB | P5_02 |
| Backups | Inactive | P5_01 |
| Connections | 13 / 500 (at time of screenshot) | P5_01 |

**Evidence:** Screenshots
`…_P5_01_AtlasCluster.png`,
`…_P5_02_CloudDatabase.png`,
`…_P5_03_CloudNotifications.png`,
`…_P5_04_ReplicaSetMembers.png`.

### 1.2  Read Verification

A read-only query was executed in the mongosh shell connected to the Atlas
cluster:

```javascript
db.transaction_notifications.findOne({ notification_id: "P4-N001" })
```

The query returned the complete P4-N001 document including:
- `notification_id: 'P4-N001'`
- `transaction_reference: 'P3L-RETRY-COMMIT-001'`
- `wallet_number: 'P3LW000001'`
- `channel: 'EMAIL'`, `status: 'SENT'`
- `message: { subject: 'Transfer successful', body: 'Your NGN 1.00 transfer was successful.' }`
- `created_at: ISODate('2026-10-26T19:51:55.148Z')`
- One delivery attempt with `outcome: 'SENT'`, `provider: 'SIMULATED'`

This confirms that the Portfolio 4 data is stored on, and can be read from, the
Atlas cluster. (Portfolio 4 was also carried out on this cluster: the mongosh
prompt in the Portfolio 4 screenshots shows `Atlas atlas-mkcu1x-shard-0`.)

**Evidence:** Screenshot `…_P5_05_CloudRead.png`.

---

## 2  Replication

### 2.1  What is Replication? *(General explanation)*

Replication is the process of maintaining identical copies of data across
multiple database server nodes.  In MongoDB, this is achieved through a
**replica set**: a group of `mongod` processes that hold the same data set.

A replica set consists of:

- **One primary node** — receives all write operations
- **One or more secondary nodes** — replicate the primary's oplog
  (operations log) and maintain near-identical copies of the data
- Optionally, an **arbiter** — participates in elections but holds no data

Writes are applied to the primary and asynchronously replicated to secondaries
via the oplog.  If the primary becomes unavailable, an automatic **election**
promotes one of the secondaries to primary (MongoDB, 2024a).

### 2.2  Observed Replication in KoraPay

The `db.hello()` command (screenshot P5_04) confirmed:

```
replicaSet: 'atlas-mkcu1x-shard-0'
isPrimary: true
primary: 'ac-mq2siev-shard-00-01.mqgqgau.mongodb.net:27017'
members: [
  'ac-mq2siev-shard-00-00.mqgqgau.mongodb.net:27017',
  'ac-mq2siev-shard-00-01.mqgqgau.mongodb.net:27017',
  'ac-mq2siev-shard-00-02.mqgqgau.mongodb.net:27017'
]
```

This shows three replica set members.  The connected session was on the primary
(`…shard-00-01`).  The other two members (`…shard-00-00` and `…shard-00-02`)
are therefore the secondaries. Their individual state and replication lag were
not checked.

### 2.3  Why Replication Matters for KoraPay *(Conceptual)*

For a fintech notification system like KoraPay, replication provides:

1. **Data redundancy:** If one node's storage fails, two other copies of every
   notification document survive.
2. **Read availability:** Secondary nodes can serve read queries (with
   appropriate read preferences), distributing read load.
3. **Automatic failover:** If the primary fails, a secondary is elected as the
   new primary without manual intervention, reducing downtime.

> [!IMPORTANT]
> **No failover was tested in this portfolio.**  The three-node replica set was
> observed, but no node was shut down or failed over.  The failover behaviour
> described above is based on documented MongoDB replica set behaviour
> (MongoDB, 2024a), not on an experiment conducted here.

---

## 3  Availability and Consistency

### 3.1  High Availability *(General explanation)*

High availability (HA) means that the database continues to accept operations
even when individual components fail.  MongoDB's replica set architecture
supports HA through automatic primary elections: if the primary node becomes
unreachable, the remaining members elect a new primary, typically within
10–12 seconds (MongoDB, 2024b).

The cluster appears to be on the free tier: P5_01 shows a 512 MB storage limit
and a tier label cut off as "FR…". The exact tier name (for example M0) is not
visible. P5_01 lists a single region, so all three nodes are in the **same
AWS region** (`eu-west-3`, Paris).  This provides resilience against
single-node failures within the region but not against a full regional outage.

### 3.2  Consistency Model *(General explanation)*

MongoDB uses a **tunable consistency model** controlled by write concern and
read concern settings:

| Setting | Description |
|---------|------------|
| **Write concern `w: 1`** (default) | The primary acknowledges the write before replication to secondaries |
| **Write concern `w: "majority"`** | The primary waits until a majority of members (including itself) have acknowledged the write |
| **Read concern `"local"`** (default) | Returns the most recent data on the queried node, which may be rolled back |
| **Read concern `"majority"`** | Returns only data that has been acknowledged by a majority of members |

With default settings (`w: 1`, read concern `"local"`), MongoDB prioritises
**low latency** over strict consistency.  For financial data where durability
matters, `w: "majority"` and read concern `"majority"` can be used to ensure
that acknowledged writes survive a primary failover (MongoDB, 2024c).

> [!NOTE]
> **No write-concern or read-concern experiments were conducted.**  The read
> in P5_05 used default settings.  The consistency discussion above is based on
> MongoDB documentation, not observed behaviour.

### 3.3  CAP Theorem Perspective *(General explanation)*

The CAP theorem states that a distributed system can simultaneously guarantee
at most two of three properties: **Consistency**, **Availability**, and
**Partition tolerance** (Brewer, 2000; Gilbert & Lynch, 2002).

MongoDB is a **CP-leaning** system:

- Under normal operation, all writes go to a single primary, and by default
  reads do too. With the defaults in Section 3.2, an acknowledged write can
  still be rolled back after a failover. Reads reflect only majority-acknowledged
  writes when `w: "majority"` and read concern `"majority"` are used.
- During a network partition, if a primary is isolated from the majority of
  members, it steps down and the partition with the majority elects a new
  primary.  The minority partition becomes **unavailable** for writes until
  connectivity is restored.
- Availability can be improved by relaxing consistency (e.g., reading from
  secondaries with `readPreference: "secondaryPreferred"`), but this may
  return stale data.

For KoraPay notifications, CP behaviour is appropriate: it is better to briefly
refuse writes during a partition than to allow conflicting notification records
on both sides of the split.

---

## 4  Disaster Recovery and Backups

### 4.1  Observed Backup Status

The Atlas cluster overview (screenshot P5_01) shows:

> **Disaster Recovery:** Backups Inactive

This means that Atlas continuous backups and point-in-time recovery are **not
currently enabled** for `korapay-cluster`.

### 4.2  Replication Is Not a Backup

> [!WARNING]
> **Replication does not replace backups.**  A replica set protects against
> hardware failure by maintaining multiple copies of the data, but it does
> **not** protect against:
>
> - **Accidental deletion** — a `deleteMany({})` or `drop()` command replicates
>   to all members instantly
> - **Application bugs** — corrupted writes propagate through the oplog
> - **Schema mistakes** — a validator change or index drop applies cluster-wide
>
> Backups provide the ability to restore the database to a specific point in
> time before the destructive event occurred.

### 4.3  Recommended Actions *(Proposed — not implemented)*

For a production KoraPay deployment, the following would be recommended:

1. **Enable Atlas continuous backups** with point-in-time recovery to protect
   against logical errors and accidental deletions.
2. **Configure backup retention** policies appropriate to the regulatory
   requirements of a Nigerian fintech platform.
3. **Test restore procedures** periodically to confirm that backups are usable.

> [!NOTE]
> None of these actions were implemented in this portfolio.  They are listed as
> recommendations based on general best practice for cloud database deployments.

---

## 5  Sharding *(Proposed — Not Implemented)*

> [!IMPORTANT]
> **Sharding was not implemented or tested.**  This section is an architectural
> discussion of how sharding *could* be applied to a notification system at
> scale.  It is clearly labelled as a proposed future approach.

### 5.1  What is Sharding? *(General explanation)*

Sharding is MongoDB's strategy for **horizontal scaling**: distributing data
across multiple machines (shards) so that no single server holds the entire
data set.  Each shard is itself a replica set, providing both scalability and
redundancy (MongoDB, 2024d).

A sharded cluster has three components:

1. **Shards** — each holds a subset of the data
2. **Config servers** — store metadata about which data resides on which shard
3. **`mongos` routers** — direct client queries to the correct shard(s)

### 5.2  Potential Shard Key for Notifications

If the `transaction_notifications` collection grew to millions of documents,
a shard key would need to be chosen.  Candidates include:

| Candidate shard key | Pros | Cons |
|---------------------|------|------|
| `notification_id` (hashed) | Even distribution; targeted queries by ID | Range queries on notification_id are scattered |
| `wallet_number` (hashed) | Co-locates all notifications for one wallet on a single shard | Hot shards if some wallets generate disproportionate traffic |
| `{ wallet_number: 1, created_at: 1 }` (compound) | Range queries by wallet and date stay on one shard | Requires careful zone configuration to avoid monotonic growth |

For the KoraPay use case, a **hashed `notification_id`** key would likely give
the most even write distribution. The IDs themselves are sequential
(`P4-N001`, `P4-N002`, …), but hashing spreads them across shards.

### 5.3  Why Sharding Is Not Needed Now

The current collection contains **6 documents** occupying **1.69 kB** of data.
A single replica set can handle millions of documents before sharding becomes
beneficial.  Sharding adds operational complexity (config servers, mongos
routing, chunk migration) that is not justified at this scale.

---

## 6  Relationship to the KoraPay System

### 6.1  PostgreSQL and MongoDB in Context

The KoraPay Wallet case study uses two database systems:

| Database | Role | Portfolios |
|----------|------|-----------|
| **PostgreSQL** | Core financial data: customers, wallets, transactions, ledger entries | 1, 2, 3 (and a separate local replication test in 5) |
| **MongoDB (Atlas)** | Transaction notification documents | 4, 5 |

PostgreSQL handles the ACID-critical operations — atomic transfers, row-level
locking, foreign-key referential integrity, and double-entry ledger balancing.
MongoDB handles the notification metadata, which benefits from a flexible
document model with embedded message content and delivery-attempt arrays.

### 6.2  Integration Caveat

> [!WARNING]
> **No cross-database integration is implemented.**  The `transaction_reference`
> and `wallet_number` fields in MongoDB notification documents are plain strings
> that correspond to identifiers in the PostgreSQL schema, but there is no
> automated synchronisation, foreign-key enforcement, or distributed transaction
> spanning both databases.  In a production system, an application-level service
> would be responsible for coordinating writes across both stores.

### 6.3  Cloud Deployment Relevance

Hosting the notification store on MongoDB Atlas — a managed cloud service with
built-in replication — demonstrates how a fintech platform might deploy
supplementary data stores independently of the primary relational database.
The Atlas cluster provides:

- Managed infrastructure (no manual `mongod` administration)
- Automatic replica set elections (documented behaviour; not tested)
- Monitoring (the activity charts in P5_01; alert settings were not checked)
- The ability to scale to larger tiers or enable sharding if needed

---

## 7  Local PostgreSQL Replication Experiment

### 7.1  What was run

I ran a separate PostgreSQL 18 replication experiment on my own machine, using
Docker Desktop 4.97.0 (P5_06) and the `postgres:18` image. It had one primary
(`korapay-pg-primary`, host port 5433) and one standby replica
(`korapay-pg-replica`, host port 5434), defined in `docker-compose.yml`.
`replica-entrypoint.sh` copies the primary with `pg_basebackup` on first start,
then runs the replica as a hot standby using replication slot `replica1_slot`.

### 7.2  Manual setup

The replica did not start at first. I then set up replication access
manually on the primary:

1. created the `replicator` role;
2. added a `pg_hba.conf` rule allowing replication connections from the
   Docker network;
3. reloaded the configuration. `pg_reload_conf()` returned `t` (P5_08).

The replica was running again afterwards. `docker ps -a` (P5_07, P5_08)
showed the primary "Up About an hour (healthy)" and the replica "Up 51
seconds". The commands used for steps 1 and 2 were not saved; only the
reload result is shown.

### 7.3  Results

| Check | Evidence | Result |
|---|---|---|
| Replication connection on the primary (`pg_stat_replication`) | P5_09 | One connection: `walreceiver`, client `172.18.0.3`, state `streaming`, sync_state `async` |
| Test row written on the primary, read on the replica | P5_10 | `CREATE TABLE`, `INSERT 0 1` on the primary; the replica returns `1 \| Replication is working` |
| Replica is a standby (`pg_is_in_recovery()`) | P5_11 | `t` |

**What it shows.** The replica received changes from the primary by
**asynchronous streaming replication**: the primary sends its write-ahead log
(WAL) to the standby, and does not wait for the standby before confirming a
commit (PostgreSQL Global Development Group, 2025). The standby was in
recovery mode, so it accepted reads but not writes.

**Asynchronous means a short lag is possible.** If the primary failed, a
commit that had not yet reached the replica could be lost. The lag was not
measured.

### 7.4  Status of the scripts

- **`primary-init/01_replication.sh` has not been tested.** It was added
  afterwards to repeat the manual role and `pg_hba.conf` setup automatically.
  The `postgres` image runs scripts in `/docker-entrypoint-initdb.d` only when
  the data directory is empty, and this script has not been run against a
  fresh database.
- **Its subnet rule is specific to this experiment.** It allows
  `172.18.0.0/16`, the Docker network used here (the replica connected from
  `172.18.0.3`). Docker may assign a different subnet on another machine or
  network.

### 7.5  What it does not show

It does not show replication of the KoraPay financial tables, failover or
promotion of the replica, recovery, synchronous replication, replication lag,
or any connection with MongoDB Atlas.

---

## 8  Limitations

1. **No failover test.**  No node was shut down or failed over.  The automatic
   election mechanism is described from documentation, not observed.

2. **No backup or recovery test.**  Backups are inactive (P5_01).  No restore
   was attempted.

3. **No sharding.**  Sharding is discussed as a proposed architecture.  The
   cluster is a single replica set.

4. **No write-concern or read-concern experiments.**  All operations used
   default settings.

5. **No cross-region replication.**  All three nodes are in the same AWS region
   (`eu-west-3`).  Multi-region deployment was not configured or tested.

6. **No performance or latency benchmarking.**  No measured comparison between
   local and cloud reads, or between primary and secondary reads.

7. **No PostgreSQL integration.**  The relationship between MongoDB notification
   documents and PostgreSQL transaction records is conceptual only.

8. **Simulated delivery.**  As in Portfolio 4, all notification delivery is
   simulated.  No real messages were sent.

9. **Free-tier limitations.**  P5_01 shows a 512 MB storage limit and a
   500-connection limit. Other free-tier limits, such as shared resources and
   no continuous backups, come from Atlas documentation and were not checked.

10. **Local PostgreSQL experiment.**  This was a single run of one test table
    in Docker on one machine. The primary initialization script has not been
    tested on a fresh database, and its subnet rule only fits this Docker
    network (Section 7).

---

## 9  Screenshot Evidence Index

| Screenshot | Shows |
|-----------|-------|
| `…_P5_01_AtlasCluster.png` | Atlas Clusters page: `korapay-cluster`, AWS Paris (eu-west-3), Replica Set – 3 nodes, v8.0.34, Backups Inactive, 13/500 connections, 73.65 kB / 512 MB |
| `…_P5_02_CloudDatabase.png` | Data Explorer: `korapay_nosql` database (36.86 kB storage, 1.69 kB data, 1 collection, 2 indexes); "Connected to korapay-cluster" |
| `…_P5_03_CloudNotifications.png` | `transaction_notifications`: 6 documents, 2 indexes; P4-N001 (SENT, EMAIL) and P4-N002 (SENT, SMS) visible |
| `…_P5_04_ReplicaSetMembers.png` | `db.hello()`: replica set `atlas-mkcu1x-shard-0`, `isPrimary: true`, primary `…shard-00-01`, 3 members |
| `…_P5_05_CloudRead.png` | `findOne({ notification_id: "P4-N001" })` returning complete document with SENT status and SIMULATED attempt |
| `…_P5_06_DockerVersion.png` | `docker version`: Docker Desktop 4.97.0, Engine 29.9.2 |
| `…_P5_07_DockerContainers.png` | `docker ps -a`: `korapay-pg-replica` up 51 seconds, `korapay-pg-primary` up about an hour (healthy) |
| `…_P5_08_ConfigReloadAndContainers.png` | `pg_reload_conf` returned `t`, followed by the same `docker ps -a` output |
| `…_P5_09_ReplicationStreaming.png` | `pg_stat_replication` on the primary: `walreceiver`, `172.18.0.3`, `streaming`, `async` |
| `…_P5_10_ReplicationTest.png` | Table and row created on the primary; the replica returns `1 \| Replication is working` |
| `…_P5_11_StandbyCheck.png` | `pg_is_in_recovery()` on the replica returns `t` |
| `…_P5_12_AnalysisInIDE.png` | The local-replication section of this document open in the Antigravity IDE (not evidence of a result) |

---

## 10  Sources

- Brewer, E. (2000). 'Towards Robust Distributed Systems'. *Proceedings of the
  19th Annual ACM Symposium on Principles of Distributed Computing (PODC)*.
  ACM. Available at: https://people.eecs.berkeley.edu/~brewer/cs262b-2004/PODC-keynote.pdf

- Gilbert, S. and Lynch, N. (2002). 'Brewer's Conjecture and the Feasibility of
  Consistent, Available, Partition-Tolerant Web Services'. *ACM SIGACT News*,
  33(2), pp. 51–59. doi: 10.1145/564585.564601

- MongoDB (2024a). *Replication — MongoDB Manual*. Available at:
  https://www.mongodb.com/docs/manual/replication/

- MongoDB (2024b). *Replica Set Elections — MongoDB Manual*. Available at:
  https://www.mongodb.com/docs/manual/core/replica-set-elections/

- MongoDB (2024c). *Write Concern — MongoDB Manual*. Available at:
  https://www.mongodb.com/docs/manual/reference/write-concern/

- MongoDB (2024d). *Sharding — MongoDB Manual*. Available at:
  https://www.mongodb.com/docs/manual/sharding/

- MongoDB (2024e). *MongoDB Atlas Documentation*. Available at:
  https://www.mongodb.com/docs/atlas/

- PostgreSQL Global Development Group (2025). *PostgreSQL 18 Documentation:
  Log-Shipping Standby Servers (Streaming Replication)*. Available at:
  https://www.postgresql.org/docs/18/warm-standby.html

The MongoDB and PostgreSQL entries are online manuals that change over time
(accessed October 2026).

---

## 11  AI Assistance Disclosure

- **ChatGPT:** used for documentation.
- **Google Antigravity / Gemini:** used to look out for errors.
- **Claude:** final review and cleanup of this portfolio's documents and file
  names.
