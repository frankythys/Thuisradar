#!/usr/bin/env bash
# Laadt stubs + schema.sql + alle migraties in een verse lokale database en
# draait daarna elke *_test.sql. Vereist een lokale Postgres (psql).
# Gebruik: PGHOST=... PGPORT=... PGUSER=... supabase/tests/run.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
db="thuisradar_test"
psql_q=(psql -v ON_ERROR_STOP=1 -q)

"${psql_q[@]}" -d postgres -c "drop database if exists $db" -c "create database $db" >/dev/null 2>&1
"${psql_q[@]}" -d "$db" -f "$here/stubs.sql" >/dev/null 2>&1
"${psql_q[@]}" -d "$db" -f "$root/schema.sql" >/dev/null 2>&1
for f in "$root"/migrations/0*.sql; do
  # pg_net bestaat lokaal niet; de stub in stubs.sql neemt het over.
  sed 's/^create extension if not exists pg_net;//' "$f" | "${psql_q[@]}" -d "$db" >/dev/null 2>&1 \
    || { echo "Migratie faalt: $f"; exit 1; }
done

for t in "$here"/*_test.sql; do
  echo "== $(basename "$t")"
  "${psql_q[@]}" -d "$db" -f "$t"
done
echo "Alle SQL-tests geslaagd."
