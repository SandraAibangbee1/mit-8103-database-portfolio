#!/bin/bash
set -e

# Portfolio 5 primary initialization script (mounted into
# /docker-entrypoint-initdb.d by docker-compose.yml).
#
# NOT TESTED: written after the experiment to repeat the manual setup
# (create the replicator role, add the pg_hba.conf rule). The postgres image
# runs it only when the data directory is empty, and it has not been run
# against a fresh database.
#
# The 172.18.0.0/16 subnet is the Docker network used in this experiment.
# Another machine or network may use a different subnet.

# Create the user used by the replica.
psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v repl_password="$REPLICATION_PASSWORD" <<'EOSQL'
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD :'repl_password';
EOSQL

# Allow replication connections from this Docker network.
echo "host replication replicator 172.18.0.0/16 scram-sha-256" >> "$PGDATA/pg_hba.conf"