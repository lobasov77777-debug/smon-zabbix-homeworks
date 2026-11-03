#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
export MYSQL_ROOT_PASSWORD
: "${MYSQL_ROOT_PASSWORD:?Set MYSQL_ROOT_PASSWORD before running}"
if docker compose version >/dev/null 2>&1; then
  compose=(docker compose)
else
  compose=(docker-compose)
fi
project="${COMPOSE_PROJECT_NAME:-mysql1206demo}"
dc() { "${compose[@]}" -p "$project" "$@"; }
sql() {
  local node=$1
  shift
  dc exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" "$node" mysql -uroot "$@"
}
ready() {
  local node=$1
  for attempt in {1..90}; do
    if sql "$node" --protocol=TCP -h 127.0.0.1 -N -e 'SELECT 1' 2>/dev/null | grep -qx 1; then return; fi
    sleep 2
  done
  dc logs --tail 15 "$node"
  return 1
}
dc up -d source
ready source
dc up -d replica
ready replica

# This setup expects fresh, dedicated project volumes.
secret=$(openssl rand -hex 12)
sql source <<SQL
CREATE USER 'replicator'@'%' IDENTIFIED BY '$secret';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
SQL
sql replica <<SQL
SET PERSIST super_read_only = ON;
CHANGE REPLICATION SOURCE TO SOURCE_HOST = 'source',
  SOURCE_USER = 'replicator', SOURCE_PASSWORD = '$secret',
  SOURCE_AUTO_POSITION = 1, GET_SOURCE_PUBLIC_KEY = 1;
START REPLICA;
SQL

printf '\n=== Server roles ===\n'
for node in source replica; do
  printf '\n[%s]\n' "$node"
  sql "$node" --table -e 'SELECT @@server_id AS server_id, @@gtid_mode AS gtid_mode, @@read_only AS read_only, @@super_read_only AS super_read_only'
done

printf '\n[source] CREATE DATABASE, CREATE TABLE, INSERT\n'
sql source -e "CREATE DATABASE replication_demo; CREATE TABLE replication_demo.probe (id INT PRIMARY KEY, note VARCHAR(80)); INSERT INTO replication_demo.probe VALUES (1206, 'Written on source');"
gtids=$(sql source -N -e 'SELECT @@GLOBAL.gtid_executed')
[[ $(sql replica -N -e "SELECT WAIT_FOR_EXECUTED_GTID_SET('$gtids', 60)") == 0 ]]
printf '[replica] SELECT after waiting for source GTIDs\n'
sql replica --table -e 'SELECT * FROM replication_demo.probe'
[[ $(sql replica -N -e 'SELECT note FROM replication_demo.probe WHERE id=1206') == 'Written on source' ]]

printf '\n[source] UPDATE id=1206\n'
sql source -e "UPDATE replication_demo.probe SET note='Updated on source' WHERE id=1206"
gtids=$(sql source -N -e 'SELECT @@GLOBAL.gtid_executed')
[[ $(sql replica -N -e "SELECT WAIT_FOR_EXECUTED_GTID_SET('$gtids', 60)") == 0 ]]
printf '[replica] SELECT after waiting for source GTIDs\n'
sql replica --table -e 'SELECT * FROM replication_demo.probe'
[[ $(sql replica -N -e 'SELECT note FROM replication_demo.probe WHERE id=1206') == 'Updated on source' ]]

printf '\n[replica] Attempt to write directly\n'
if denied=$(sql replica -e "INSERT INTO replication_demo.probe VALUES (1207,'Direct write')" 2>&1); then
  printf 'Unexpected: direct write succeeded\n' >&2
  exit 1
fi
printf '%s\n' "$denied"
[[ "$denied" == *'ERROR 1290'* ]]

printf '\n[replica] SHOW REPLICA STATUS (selected fields)\n'
status=$(sql replica -e 'SHOW REPLICA STATUS\G')
printf '%s\n' "$status" | grep -E 'Source_Host:|Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Last_(IO|SQL)_Errno:|Auto_Position:'
grep -Eq 'Replica_IO_Running: Yes' <<< "$status"
grep -Eq 'Replica_SQL_Running: Yes' <<< "$status"
grep -Eq 'Last_IO_Errno: 0' <<< "$status"
grep -Eq 'Last_SQL_Errno: 0' <<< "$status"
