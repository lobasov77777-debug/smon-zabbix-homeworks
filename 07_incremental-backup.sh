#!/bin/bash
set -euo pipefail
umask 077

source_dir=/home/vagrant
remote=netologybackup@192.168.56.42
root=/srv/netology-backups/snapshots
ssh_options=(-n -i /home/vagrant/.ssh/netology_backup -o BatchMode=yes -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/vagrant/.ssh/netology_backup_known_hosts)
ssh_command='ssh -i /home/vagrant/.ssh/netology_backup -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/vagrant/.ssh/netology_backup_known_hosts'

exec 9>/tmp/netology-snapshots.lock
flock -n 9
names=$(ssh "${ssh_options[@]}" "$remote" /usr/local/bin/netology-snapshots list)
previous=$(printf '%s\n' "$names" | tail -n 1)
id=$(date -u +%Y%m%dT%H%M%SZ-%N)
pending=$id
cleanup() {
    code=$?
    if [[ -n "$pending" ]]; then
        ssh "${ssh_options[@]}" "$remote" /usr/local/bin/netology-snapshots abort "$pending" || true
    fi
    exit "$code"
}
trap cleanup EXIT

ssh "${ssh_options[@]}" "$remote" /usr/local/bin/netology-snapshots prepare "$id"
options=(-a --checksum --delete)
if [[ -n "$previous" ]]; then
    [[ "$previous" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]{9}$ ]]
    options+=(--link-dest="$root/$previous")
fi
rsync "${options[@]}" -e "$ssh_command" "$source_dir/" "$remote:$root/.incomplete-$id/"
ssh "${ssh_options[@]}" "$remote" /usr/local/bin/netology-snapshots commit "$id"
pending=''
printf 'SAVED %s BASE=%s\n' "$id" "${previous:-FULL}"
