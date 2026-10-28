# Portfolio 5: Distributed Database and Cloud Deployment

- **Student:** Sandra Aibangbee
- **Student ID:** 2026/A/MIT/0301/301897710
- **Course:** MIT 8103 Advanced Database Systems

---

## 1. Purpose

This portfolio has two separate parts:

1. **MongoDB Atlas (observed).** The Portfolio 4 notification data is stored on a cloud-hosted MongoDB Atlas cluster, `korapay-cluster`, on AWS Paris (`eu-west-3`). I observed its three-node replica set and read data from it.
2. **Local PostgreSQL replication (run).** In a separate experiment, I ran a PostgreSQL 18 primary and one standby replica in Docker on my own machine. A test row written on the primary was read back from the replica.

The analysis is in [Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_DistributedCloudAnalysis.md](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_DistributedCloudAnalysis.md).

> [!IMPORTANT]
> **Not tested:** failover, backup and recovery, sharding, cross-region replication, read/write-concern settings and performance. The discussion of these topics is based on documentation, not on experiments.

---

## 2. Part 1: MongoDB Atlas observations

| Screenshot | What it shows |
|---|---|
| P5_01 | Atlas Clusters page: `korapay-cluster`, version 8.0.34, AWS / Paris (eu-west-3), Replica Set – 3 nodes, **Backups Inactive**, 13/500 connections, 73.65 kB / 512.00 MB data size |
| P5_02 | Data Explorer: database `korapay_nosql`, storage 36.86 kB, data 1.69 kB, 1 collection, 2 indexes; "Connected to korapay-cluster" |
| P5_03 | `transaction_notifications`: 6 documents, 2 indexes; P4-N001 (SENT, EMAIL) and P4-N002 (SENT, SMS) visible |
| P5_04 | `db.hello()` in mongosh: replica set `atlas-mkcu1x-shard-0`, `isPrimary: true`, primary `…shard-00-01`, three members `…shard-00-00/01/02` |
| P5_05 | `findOne({ notification_id: "P4-N001" })` returns the full document from the cluster |

---

## 3. Part 2: Local PostgreSQL replication experiment

### Setup

- **Tools:** Docker Desktop 4.97.0 with Docker Engine 29.9.2 (P5_06), and the `postgres:18` image.
- **Files:**
  - [`docker-compose.yml`](./docker-compose.yml) defines two containers:
    - `korapay-pg-primary` on host port 5433;
    - `korapay-pg-replica` on host port 5434.
  - [`replica-entrypoint.sh`](./replica-entrypoint.sh): on first start it copies the primary with `pg_basebackup`, then starts PostgreSQL as a hot standby.
  - [`primary-init/01_replication.sh`](./primary-init/01_replication.sh): creates the `replicator` role and adds the `pg_hba.conf` rule.

### What happened

1. Both containers were started. The replica did not start at first.
2. On the primary, I set up replication access manually:
   - created the `replicator` role;
   - added a `pg_hba.conf` rule allowing replication connections from the Docker network;
   - reloaded the configuration (`pg_reload_conf()` returned `t`, shown in P5_08).
3. The replica was running again afterwards. `docker ps -a` showed both containers up (P5_07, P5_08): the primary for about an hour and the replica for 51 seconds.
4. The replication checks then passed:

| Screenshot | Command | Result |
|---|---|---|
| P5_09 | `pg_stat_replication` on the primary | One connection: `walreceiver`, client `172.18.0.3`, state `streaming`, sync_state `async` |
| P5_10 | Create `replication_test` and insert a row on the primary; select it on the replica | The replica returns `1 \| Replication is working` |
| P5_11 | `SELECT pg_is_in_recovery()` on the replica | `t`: the replica is running as a standby |

### Status of the files

- **`primary-init/01_replication.sh` was added after the experiment and is untested on a fresh database.** The `postgres` image only runs scripts in `/docker-entrypoint-initdb.d` when the data directory is empty.
- **Its subnet rule is specific to this Docker network.** The script allows `172.18.0.0/16`, the network used here (the replica connected from `172.18.0.3`). Another machine may use a different subnet.
- The role and the `pg_hba.conf` rule were set up manually, and the commands used were not saved. Only the reload result is shown (P5_08).

### What this experiment does not show

It shows streaming replication of one test table in a local setup. It does not show replication of the KoraPay tables, failover, recovery, synchronous replication or any link to MongoDB Atlas.

### Running it again (untested)

From this folder, with Docker Desktop running:

```bash
docker compose up -d
docker exec korapay-pg-primary psql -U korapay -d korapay_db -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"
docker exec korapay-pg-replica psql -U korapay -d korapay_db -c "SELECT pg_is_in_recovery();"
```

The passwords in `docker-compose.yml` are demo values only.

---

## 4. Files

| File | Notes |
|---|---|
| [P5 analysis](./Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_DistributedCloudAnalysis.md) | Analysis of both parts |
| `docker-compose.yml`, `replica-entrypoint.sh`, `primary-init/01_replication.sh` | Docker setup. These names are kept because Docker and the compose file refer to them |

### Screenshots

All file names start with `Aibangbee_Sandra_2026_A_MIT_0301_301897710_`.

| File | Shows |
|---|---|
| [P5_01_AtlasCluster](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_01_AtlasCluster.png) | Atlas cluster overview |
| [P5_02_CloudDatabase](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_02_CloudDatabase.png) | Atlas Data Explorer: `korapay_nosql` |
| [P5_03_CloudNotifications](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_03_CloudNotifications.png) | The 6 notification documents in Atlas |
| [P5_04_ReplicaSetMembers](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_04_ReplicaSetMembers.png) | `db.hello()`: replica set members |
| [P5_05_CloudRead](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_05_CloudRead.png) | Read of P4-N001 from Atlas |
| [P5_06_DockerVersion](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_06_DockerVersion.png) | `docker version` |
| [P5_07_DockerContainers](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_07_DockerContainers.png) | `docker ps -a`: both containers up (replica 51 s) |
| [P5_08_ConfigReloadAndContainers](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_08_ConfigReloadAndContainers.png) | `pg_reload_conf` = `t`, then the same `docker ps -a` output. Previously named `…P5_Docker_Containers.png -.png` |
| [P5_09_ReplicationStreaming](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_09_ReplicationStreaming.png) | `pg_stat_replication`: streaming, async |
| [P5_10_ReplicationTest](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_10_ReplicationTest.png) | Test row written on the primary, read on the replica |
| [P5_11_StandbyCheck](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_11_StandbyCheck.png) | `pg_is_in_recovery()` = `t` on the replica |
| [P5_12_AnalysisInIDE](./screenshots/Aibangbee_Sandra_2026_A_MIT_0301_301897710_P5_12_AnalysisInIDE.png) | The analysis's local-replication section open in the Antigravity IDE. Previously named `P5_GitHub_Push`, but it does not show a push |

---

## 5. AI assistance

- **ChatGPT:** used for documentation.
- **Google Antigravity / Gemini:** used to look out for errors.
- **Claude:** final review and cleanup of this portfolio's documents and file names.
