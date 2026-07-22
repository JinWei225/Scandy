#!/bin/bash
# Shared helpers for the Scandy deployment scripts.
# Sourced, never executed directly.

# Resolve paths relative to this file so the scripts work from any directory.
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$DEPLOY_DIR/.." && pwd)"

BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
DIST_DIR="$FRONTEND_DIR/dist"

BACKEND_PORT="${SCANDY_BACKEND_PORT:-5001}"
LOG_FILE="$BACKEND_DIR/waitress.log"
PID_FILE="$BACKEND_DIR/waitress.pid"

# --- Output -----------------------------------------------------------------
# Colour only when writing to a terminal, so piped/redirected output stays clean.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_BOLD=$'\033[1m'
else
    C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''
fi

heading() { printf '%s\n%s%s%s\n%s\n' "======================================" \
                                      "$C_BOLD" "$1" "$C_RESET" \
                                      "======================================"; }
step()    { printf '%s→%s %s\n'  "$C_BLUE"   "$C_RESET" "$1"; }
ok()      { printf '%s✓%s %s\n'  "$C_GREEN"  "$C_RESET" "$1"; }
warn()    { printf '%s!%s %s\n'  "$C_YELLOW" "$C_RESET" "$1" >&2; }
err()     { printf '%s✗%s %s\n'  "$C_RED"    "$C_RESET" "$1" >&2; }

# die "what went wrong" "how to fix it" (hint optional)
die() {
    err "$1"
    [ -n "${2:-}" ] && printf '  %s\n' "$2" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed." "${2:-}"
}

# --- Backend process ---------------------------------------------------------
# PID of whatever holds the backend port, empty if the port is free.
# "no match" is a normal answer here, not an error: lsof exits 1 when it finds
# nothing, which under `set -o pipefail` would otherwise abort the caller.
backend_pid() {
    lsof -t -i ":$BACKEND_PORT" -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

backend_running() {
    [ -n "$(backend_pid)" ]
}

# True when the API actually answers, not merely when the port is bound. A
# process can hold the port while still failing every request.
backend_responding() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsS -m 3 -o /dev/null "http://127.0.0.1:$BACKEND_PORT/api/categories" 2>/dev/null
    else
        backend_running   # no curl: fall back to the weaker check
    fi
}

# Prefer the project venv; uv sync creates it and it is the documented setup.
detect_python() {
    if [ -x "$PROJECT_ROOT/.venv/bin/python" ]; then
        PYTHON="$PROJECT_ROOT/.venv/bin/python"
    elif command -v python3 >/dev/null 2>&1; then
        PYTHON="$(command -v python3)"
        warn "No .venv found — falling back to $PYTHON"
    else
        die "No Python interpreter found." "Install Python 3.13+, then run: uv sync"
    fi
}

# Fail here with an actionable message rather than letting the server die on an
# ImportError buried in a traceback.
check_python_deps() {
    if ! "$PYTHON" - <<'PY' 2>/dev/null
import importlib.util, sys
missing = [m for m in ("flask", "flask_cors", "waitress") if not importlib.util.find_spec(m)]
sys.exit(1 if missing else 0)
PY
    then
        die "Backend dependencies are missing from $PYTHON." \
            "Run: uv sync   (or: pip install -r backend/requirements.txt)"
    fi
}

# --- nginx -------------------------------------------------------------------
nginx_servers_dir() {
    if [ -d "/opt/homebrew/etc/nginx" ]; then
        echo "/opt/homebrew/etc/nginx/servers"      # Apple Silicon Homebrew
    elif [ -d "/usr/local/etc/nginx" ]; then
        echo "/usr/local/etc/nginx/servers"          # Intel Homebrew
    else
        echo "/etc/nginx/conf.d"                     # Linux
    fi
}

# nginx rewrites its argv to "nginx: master process ...", so `pgrep -x nginx`
# never matches a running server. Match the master process line instead.
nginx_running() {
    pgrep -f 'nginx: master process' >/dev/null 2>&1
}
