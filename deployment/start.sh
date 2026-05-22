#!/bin/bash

# ReceiptOCR Startup Script
# Starts both backend and nginx for production access

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "======================================"
echo "Starting ReceiptOCR Application"
echo "======================================"
echo ""

# Check if backend is already running
if lsof -i :5001 > /dev/null 2>&1; then
    echo "⚠️  Backend is already running on port 5001"
    echo "To restart, first run: ./deployment/stop.sh"
    exit 1
else
    echo "Starting backend server..."
    cd "$PROJECT_ROOT/backend"
    
    # Start in foreground (not background) so Ctrl+C works properly
    python3 run_waitress.py
fi

