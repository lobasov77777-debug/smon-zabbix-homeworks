#!/bin/bash

[[ -f /var/www/html/index.html ]] || exit 1

/usr/bin/timeout 1 /bin/bash -c 'exec 3<>/dev/tcp/127.0.0.1/80' \
    >/dev/null 2>&1 || exit 1

exit 0
