#!/bin/bash
#
# Show what is and is not running.
#
#   ./deployment/status.sh
#
# Exit code is 0 when the backend is serving requests, 1 otherwise, so this can
# be used in a health check.

set -uo pipefail   # no -e: this script reports failures rather than aborting on them

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

heading "Scandy status"

HEALTHY=0

# --- Backend -----------------------------------------------------------------
PID="$(backend_pid)"
if [ -z "$PID" ]; then
    err "Backend:  not running"
    printf '  Start it: %s./deployment/start.sh%s\n' "$C_BOLD" "$C_RESET"
elif backend_responding; then
    ok "Backend:  running and responding (PID $PID, port $BACKEND_PORT)"
    HEALTHY=1
else
    warn "Backend:  port $BACKEND_PORT is held by PID $PID but the API is not answering"
    printf '  Check the log: %stail -n 30 %s%s\n' "$C_BOLD" "$LOG_FILE" "$C_RESET"
fi

# --- Frontend build ----------------------------------------------------------
if [ -d "$DIST_DIR" ] && [ -f "$DIST_DIR/index.html" ]; then
    ok "Frontend: built ($DIST_DIR)"
else
    err "Frontend: not built"
    printf '  Build it: %s./deployment/deploy.sh%s\n' "$C_BOLD" "$C_RESET"
fi

# --- nginx -------------------------------------------------------------------
if ! command -v nginx >/dev/null 2>&1; then
    warn "nginx:    not installed (the API still works on port $BACKEND_PORT)"
elif ! nginx_running; then
    warn "nginx:    installed but not running"
    printf '  Start it: %ssudo nginx%s\n' "$C_BOLD" "$C_RESET"
else
    # Ask nginx for the page rather than inferring from which config files
    # exist — the config can live in the main nginx.conf or in servers/, and
    # only an actual request proves either one is working.
    if curl -fsS -m 3 -o /dev/null "http://localhost/" 2>/dev/null; then
        ok "nginx:    running and serving the app on http://localhost"

        # The proxy is a separate failure mode: nginx can serve the frontend
        # perfectly while /api/ points somewhere wrong.
        if [ "$HEALTHY" -eq 1 ]; then
            if curl -fsS -m 5 -o /dev/null "http://localhost/api/categories" 2>/dev/null; then
                ok "proxy:    /api/ reaches the backend"
            else
                warn "proxy:    http://localhost/api/ does not reach the backend"
                printf '  Check the proxy_pass line in your nginx config.\n'
            fi
        fi
    else
        warn "nginx:    running, but http://localhost did not respond"
        printf '  It may be serving a different site, or the Scandy config is not loaded.\n'
        printf '  Re-run: %s./deployment/deploy.sh%s\n' "$C_BOLD" "$C_RESET"
    fi
fi

# --- OCR backend -------------------------------------------------------------
echo ""
printf 'OCR engine: %s\n' "${OCR_BACKEND:-mlx (default)}"

echo ""
if [ -f "$LOG_FILE" ]; then
    echo "Log: $LOG_FILE"
fi

exit $(( HEALTHY == 1 ? 0 : 1 ))
