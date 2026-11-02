#!/bin/bash
set -Eeuo pipefail
umask 077

source_dir=/home/vagrant
backup_dir=/tmp/backup

finish() {
    status=$?
    if ((status == 0)); then
        logger -t netology-backup -- "SUCCESS source=$source_dir destination=$backup_dir"
    else
        logger -t netology-backup -- "ERROR exit_code=$status source=$source_dir destination=$backup_dir"
    fi
    exit "$status"
}
trap finish EXIT

exec 9>/tmp/netology-home-backup.lock
flock -n 9
test -d "$source_dir"
mkdir -p "$backup_dir"
rsync -a --delete --itemize-changes --stats "$source_dir/" "$backup_dir/"
