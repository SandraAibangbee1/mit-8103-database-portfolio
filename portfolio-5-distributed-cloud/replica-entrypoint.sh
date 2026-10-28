#!/bin/bash
set -e

# Portfolio 5 replica entrypoint (used by the "replica" service in
# docker-compose.yml). On first start it copies the primary with
# pg_basebackup (-R writes the standby settings, -C -S creates the
# replication slot replica1_slot), then starts PostgreSQL as a hot standby.
# If the data directory already exists, it skips the copy.

export PGDATA=/var/lib/postgresql/18/docker

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Replica: waiting for the primary..."
  until pg_isready -h primary -p 5432 -U korapay -d korapay_db; do
    sleep 2
  done

  mkdir -p "$PGDATA"
  chown postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"

  echo "Replica: copying the primary..."
  PGPASSWORD="$REPLICATION_PASSWORD" gosu postgres pg_basebackup \
    -h primary -p 5432 -U replicator -D "$PGDATA" \
    -R -X stream -C -S replica1_slot -c fast -v
fi

chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"
exec gosu postgres postgres -c hot_standby=on