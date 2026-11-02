#!/bin/bash
set -euo pipefail

exec 9>/run/keepalived-load.lock
flock -n 9 || exit 0

read -r load1 _ < /proc/loadavg
cpus=$(getconf _NPROCESSORS_ONLN)
adjustment=$(LC_ALL=C awk -v avg="$load1" -v cpus="$cpus" 'BEGIN {
    penalty = int(40 * avg / cpus + 0.5)
    if (penalty > 190) penalty = 190
    print -penalty
}')

install -d -m 0755 /var/lib/keepalived
printf '%s\n' "$adjustment" > /var/lib/keepalived/load_priority
logger -t keepalived-load -- \
    "load1=$load1 cpus=$cpus adjustment=$adjustment effective_priority=$((200 + adjustment))"
