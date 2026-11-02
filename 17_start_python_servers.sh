#!/bin/bash
set -euo pipefail

case "${1:-}" in
    1|3) ports=(8888 9999) ;;
    2) ports=(8888 9999 10000) ;;
    4) ports=(8888 9999 10000 10001) ;;
    *) echo "Usage: sudo bash $0 {1|2|3|4}" >&2; exit 2 ;;
esac

systemctl stop python-http@8888 python-http@9999 python-http@10000 python-http@10001

for i in "${!ports[@]}"; do
    port=${ports[$i]}
    number=$((i + 1))
    root="/srv/cluster-hw/$port"
    install -d -m 0755 "$root"
    if [[ "$1" = 4 ]]; then
        if ((number <= 2)); then domain=example1.local; else domain=example2.local; fi
        printf '%s | backend s%s | port %s\n' "$domain" "$number" "$port" > "$root/index.html"
    else
        printf 'Server %s Port %s\n' "$number" "$port" > "$root/index.html"
    fi
    printf 'Python server %s / info.txt / port %s\n' "$number" "$port" > "$root/info.txt"
    chmod 0644 "$root/index.html" "$root/info.txt"
    systemctl start "python-http@$port"
done

for port in "${ports[@]}"; do
    ready=0
    for attempt in {1..50}; do
        if curl --noproxy '*' --max-time 1 -fsS -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null; then
            ready=1
            break
        fi
        sleep 0.2
    done
    if ((ready == 0)); then echo "Python server $port is not ready" >&2; exit 1; fi
done
