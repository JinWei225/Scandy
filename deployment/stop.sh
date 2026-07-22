#!/bin/bash
#
# Stop the Scandy backend.
#
#   ./deployment/stop.sh          stop the backend
#   ./deployment/stop.sh --nginx  also stop nginx (needs sudo)
#   ./deployment/stop.sh --help
#
# nginx is left alone by default: it is a system-wide service that may be
# serving other sites, and 'nginx -s stop' would take all of them down.

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

STOP_NGINX=0
for arg in "$@"; do
    case "$arg" in
        --nginx) STOP_NGINX=1 ;;
        -h|--help)
            sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) die "Unknown option: $arg" "Run '$0 --help' for usage." ;;
    esac
done

heading "Stopping Scandy"

require_cmd lsof

# --- Backend -----------------------------------------------------------------
step "Stopping backend..."
TARGET_PID="$(backend_pid)"

if [ -z "$TARGET_PID" ]; then
    ok "Backend is not running"
else
    # SIGTERM first so Waitress can close its listener and finish in-flight
    # requests; SIGKILL would abandon an open SQLite transaction.
    kill "$TARGET_PID" 2>/dev/null || true

    STOPPED=0
    for _ in $(seq 1 10); do
        if ! kill -0 "$TARGET_PID" 2>/dev/null; then STOPPED=1; break; fi
        sleep 1
    done

    if [ "$STOPPED" -eq 0 ]; then
        warn "PID $TARGET_PID ignored SIGTERM after 10s — sending SIGKILL"
        kill -9 "$TARGET_PID" 2>/dev/null || true
        sleep 1
    fi

    if backend_running; then
        die "Port $BACKEND_PORT is still held after SIGKILL." \
            "Inspect it with: lsof -i :$BACKEND_PORT"
    fi
    ok "Backend stopped (PID $TARGET_PID)"
fi

rm -f "$PID_FILE"

# --- nginx -------------------------------------------------------------------
if [ "$STOP_NGINX" -eq 1 ]; then
    echo ""
    step "Stopping nginx..."
    if ! nginx_running; then
        ok "nginx is not running"
    elif sudo nginx -s stop 2>/dev/null; then
        ok "nginx stopped"
    else
        warn "Could not stop nginx — it may have been started by another user or service."
    fi
fi

echo ""
ok "Done"
