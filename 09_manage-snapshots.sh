#!/bin/bash
set -euo pipefail
umask 077
root=/srv/netology-backups/snapshots

valid_id() { [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]{9}$ ]]; }
list_snapshots() {
    find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
        | LC_ALL=C awk '/^[0-9]{8}T[0-9]{6}Z-[0-9]{9}$/' | LC_ALL=C sort
}

action=${1:-}
if [[ "$action" = list ]]; then
    [[ $# == 1 ]] || exit 2
    list_snapshots
    exit
fi

[[ $# == 2 ]] && valid_id "$2" || exit 2
id=$2
staging="$root/.incomplete-$id"
destination="$root/$id"

case "$action" in
    prepare)
        [[ ! -e "$staging" && ! -e "$destination" ]]
        mkdir -m 0700 -- "$staging"
        ;;
    commit)
        [[ -d "$staging" && ! -L "$staging" && ! -e "$destination" ]]
        mv -T -- "$staging" "$destination"
        names=$(list_snapshots)
        mapfile -t snapshots <<< "$names"
        remove_count=$((${#snapshots[@]} - 5))
        for ((i=0; i<remove_count; i++)); do
            old=${snapshots[$i]}
            valid_id "$old"
            [[ -d "$root/$old" && ! -L "$root/$old" ]]
            rm -rf -- "$root/$old"
            printf 'PRUNED %s\n' "$old"
        done
        ;;
    abort)
        if [[ -d "$staging" && ! -L "$staging" ]]; then rm -rf -- "$staging"; fi
        ;;
    *) exit 2 ;;
esac
