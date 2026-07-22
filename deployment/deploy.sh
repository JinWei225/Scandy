#!/bin/bash
#
# One-time setup: build the frontend and install the nginx site config.
#
#   ./deployment/deploy.sh              build the frontend and configure nginx
#   ./deployment/deploy.sh --skip-build reuse the existing frontend/dist
#   ./deployment/deploy.sh --help
#
# Re-run this after pulling new code, or after changing nginx.conf.template.

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SKIP_BUILD=0
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=1 ;;
        -h|--help)
            sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) die "Unknown option: $arg" "Run '$0 --help' for usage." ;;
    esac
done

heading "Scandy deployment"
echo "Project root: $PROJECT_ROOT"
echo ""

# --- 1. Build the frontend ---------------------------------------------------
if [ "$SKIP_BUILD" -eq 1 ]; then
    step "Skipping frontend build (--skip-build)"
    [ -f "$DIST_DIR/index.html" ] || die "frontend/dist has no index.html to reuse." \
                                         "Run without --skip-build."
    ok "Reusing existing build"
else
    step "Building frontend..."
    require_cmd npm "Install Node.js 18+ from https://nodejs.org"
    [ -d "$FRONTEND_DIR" ] || die "frontend/ not found at $FRONTEND_DIR" \
                                  "Run this script from inside the Scandy repository."

    cd "$FRONTEND_DIR"
    if [ ! -d node_modules ]; then
        step "Installing Node dependencies (first run, this takes a minute)..."
        # npm ci is reproducible but demands a lockfile in sync with package.json.
        npm ci || die "npm ci failed." "Try: cd frontend && npm install"
    fi

    npm run build || die "The frontend build failed." \
                         "Scroll up for the compiler error; fix it and re-run."

    [ -f "$DIST_DIR/index.html" ] || die "Build finished but $DIST_DIR/index.html is missing." \
                                         "Check the vue.config.js output directory."
    ok "Frontend built"
fi
echo ""

# --- 2. Install the nginx config ---------------------------------------------
step "Configuring nginx..."
require_cmd nginx "Install it with: brew install nginx   (macOS)   |   sudo apt install nginx   (Linux)"

TEMPLATE="$DEPLOY_DIR/nginx.conf.template"
[ -f "$TEMPLATE" ] || die "Missing $TEMPLATE" "The repository looks incomplete."

CONF_DIR="$(nginx_servers_dir)"
if [ ! -d "$CONF_DIR" ]; then
    step "Creating $CONF_DIR..."
    sudo mkdir -p "$CONF_DIR" || die "Could not create $CONF_DIR"
fi

# Render the template with this machine's actual dist path. Using a temp file
# means a substitution failure never leaves a half-written config installed.
RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT
# '|' as the delimiter: the project path contains '/' and may contain spaces.
sed "s|__SCANDY_DIST__|$DIST_DIR|g" "$TEMPLATE" > "$RENDERED"

if grep -q '__SCANDY_DIST__' "$RENDERED"; then
    die "Path substitution failed." "Report this as a bug."
fi

sudo cp "$RENDERED" "$CONF_DIR/scandy.conf"
ok "Installed $CONF_DIR/scandy.conf"

# Dropping a file into the servers directory only works if the main nginx.conf
# includes it. Stock installs do; a hand-edited nginx.conf often does not, and
# without this check the deploy "succeeds" while nginx never reads the file.
MAIN_CONF="$(nginx -V 2>&1 | sed -n 's/.*--conf-path=\([^ ]*\).*/\1/p')"
if [ -n "$MAIN_CONF" ] && [ -r "$MAIN_CONF" ]; then
    if ! grep -qE "^[[:space:]]*include[[:space:]].*$(basename "$CONF_DIR")/" "$MAIN_CONF"; then
        echo ""
        warn "$MAIN_CONF does not include $CONF_DIR/"
        printf '  nginx will ignore the file just installed. Add this inside its http { } block:\n'
        printf '      %sinclude %s/*.conf;%s\n' "$C_BOLD" "$CONF_DIR" "$C_RESET"
        printf '  then re-run this script.\n'
    else
        ok "nginx includes $CONF_DIR/"
    fi
fi
echo ""

# --- 3. Validate and reload --------------------------------------------------
step "Testing nginx configuration..."
if ! sudo nginx -t; then
    die "nginx rejected the configuration." \
        "The offending file is $CONF_DIR/scandy.conf — the error above names the line."
fi
ok "Configuration is valid"
echo ""

step "Reloading nginx..."
if nginx_running; then
    sudo nginx -s reload && ok "nginx reloaded"
else
    sudo nginx && ok "nginx started"
fi
echo ""

heading "Deployment complete"
echo ""
echo "Next steps:"
echo "  1. Start the backend:  ./deployment/start.sh"
echo "  2. Check everything:   ./deployment/status.sh"
echo "  3. Open the app:       http://localhost"
echo ""
echo "To reach it from your phone, see ./deployment/get-ip.sh"
echo ""
