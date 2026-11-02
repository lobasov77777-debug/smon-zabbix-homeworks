#!/bin/bash
set -euo pipefail
umask 077

destination=/home/vagrant
remote=netologybackup@192.168.56.42
root=/srv/netology-backups/snapshots
ssh_options=(-n -i /home/vagrant/.ssh/netology_backup -o BatchMode=yes -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/vagrant/.ssh/netology_backup_known_hosts)
ssh_command='ssh -i /home/vagrant/.ssh/netology_backup -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/vagrant/.ssh/netology_backup_known_hosts'

exec 9>/tmp/netology-snapshots.lock
flock -n 9
names=$(ssh "${ssh_options[@]}" "$remote" /usr/local/bin/netology-snapshots list)
[[ -n "$names" ]] || { echo 'No completed snapshots.' >&2; exit 1; }
mapfile -t snapshots <<< "$names"

if [[ $# == 0 ]]; then
    for i in "${!snapshots[@]}"; do printf '%d) %s\n' "$((i+1))" "${snapshots[$i]}"; done
    printf 'Choose snapshot [1-%d]: ' "${#snapshots[@]}"
    read -r choice
    [[ "$choice" =~ ^[1-5]$ ]] && ((choice <= ${#snapshots[@]})) || { echo 'Invalid choice.' >&2; exit 2; }
    selected=${snapshots[$((choice-1))]}
elif [[ $# == 1 ]]; then
    selected=$1
else
    echo "Usage: $0 [snapshot-id]" >&2; exit 2
fi

[[ "$selected" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]{9}$ ]] || { echo 'Invalid snapshot ID.' >&2; exit 2; }
found=0
for id in "${snapshots[@]}"; do if [[ "$id" == "$selected" ]]; then found=1; break; fi; done
((found == 1)) || { echo 'Snapshot not found.' >&2; exit 2; }

printf '\nRESTORE %s\n' "$selected"
rsync -a --checksum --delete --itemize-changes -e "$ssh_command" "$remote:$root/$selected/" "$destination/"
printf 'RESTORED %s\n' "$selected"
