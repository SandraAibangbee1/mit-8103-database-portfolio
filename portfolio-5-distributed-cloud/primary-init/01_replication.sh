#!/bin/bash
set -e

# Create the user used by the replica.
psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v repl_password="$REPLICATION_PASSWORD" <<'EOSQL'
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD :'repl_password';
EOSQL

# Allow replication connections from this Docker network.
echo "host replication replicator 172.18.0.0/16 scram-sha-256" >> "$PGDATA/pg_hba.conf"