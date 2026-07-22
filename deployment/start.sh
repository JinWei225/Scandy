#!/bin/bash
#
# Start the Scandy backend.
#
#   ./deployment/start.sh              start in the background, log to backend/waitress.log
#   ./deployment/start.sh --foreground run in this terminal (Ctrl+C to stop)
#   ./deployment/start.sh --help
#
# Everything is checked before the server is launched, so a failure tells you
# what to fix instead of dumping a traceback.

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

FOREGROUND=0
for arg in "$@"; do
    case "$arg" in
        -f|--foreground) FOREGROUND=1 ;;
        -h|--help)
            sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) die "Unknown option: $arg" "Run '$0 --help' for usage." ;;
    esac
done

heading "Starting Scandy backend"

# --- Preflight ---------------------------------------------------------------
step "Checking environment..."

[ -d "$BACKEND_DIR" ] || die "backend/ not found at $BACKEND_DIR" \
                             "Run this script from inside the Scandy repository."
[ -f "$BACKEND_DIR/run_waitress.py" ] || die "backend/run_waitress.py is missing." \
                                             "The repository looks incomplete — try: git status"

require_cmd lsof
detect_python
check_python_deps
ok "Python: $PYTHON"

# Refuse to start a second copy. Two servers on one port means the second dies
# with EADDRINUSE, or worse, two processes write to the same SQLite file.
if backend_running; then
    EXISTING_PID="$(backend_pid)"
    if backend_responding; then
        warn "Backend is already running and responding (PID $EXISTING_PID)."
        printf '  To restart: %s./deployment/stop.sh && ./deployment/start.sh%s\n' "$C_BOLD" "$C_RESET"
        exit 0
    fi
    die "Port $BACKEND_PORT is in use by PID $EXISTING_PID, but the API is not responding." \
        "Inspect it with 'lsof -i :$BACKEND_PORT', then run ./deployment/stop.sh"
fi
ok "Port $BACKEND_PORT is free"

# The frontend is served by nginx from this directory; missing it is not fatal
# for the API, but the browser would show a 404 and the cause is non-obvious.
if [ ! -d "$DIST_DIR" ]; then
    warn "frontend/dist not found — the web UI will not load."
    printf '  Build it with: %s./deployment/deploy.sh%s\n' "$C_BOLD" "$C_RESET"
fi

# --- Launch ------------------------------------------------------------------
cd "$BACKEND_DIR"

if [ "$FOREGROUND" -eq 1 ]; then
    ok "Starting in the foreground — press Ctrl+C to stop"
    echo ""
    exec "$PYTHON" run_waitress.py
fi

step "Starting server..."
# setsid/nohup so the server survives this shell exiting.
nohup "$PYTHON" run_waitress.py >>"$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > "$PID_FILE"

# Wait for the API to actually answer. Polling beats a fixed sleep: a healthy
# start is reported in ~1s, and a crash is caught instead of assumed working.
step "Waiting for the API to respond..."
for _ in $(seq 1 30); do
    if ! kill -0 "$NEW_PID" 2>/dev/null; then
        err "The server exited during startup."
        echo ""
        echo "--- last 20 lines of $LOG_FILE ---"
        tail -n 20 "$LOG_FILE" 2>/dev/null || echo "(no log output)"
        rm -f "$PID_FILE"
        exit 1
    fi
    if backend_responding; then
        echo ""
        ok "Backend running (PID $NEW_PID)"
        echo ""
        echo "  Local:  http://localhost:$BACKEND_PORT/api/"
        echo "  Logs:   tail -f $LOG_FILE"
        echo "  Stop:   ./deployment/stop.sh"
        echo ""
        exit 0
    fi
    sleep 1
done

err "The server did not respond within 30s."
echo ""
echo "--- last 20 lines of $LOG_FILE ---"
tail -n 20 "$LOG_FILE" 2>/dev/null || echo "(no log output)"
echo ""
echo "It may still be starting. Check with: ./deployment/status.sh"
exit 1
