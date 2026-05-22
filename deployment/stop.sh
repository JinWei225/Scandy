#!/bin/bash

# ReceiptOCR Stop Script
# Stops backend and nginx

echo "======================================"
echo "Stopping ReceiptOCR Application"
echo "======================================"
echo ""

# Stop backend
echo "Stopping backend..."
if lsof -i :5001 > /dev/null 2>&1; then
    # Get PID and kill it
    PID=$(lsof -t -i :5001)
    kill -9 $PID 2>/dev/null && echo "✓ Backend stopped (PID: $PID)" || echo "Failed to stop backend"
else
    echo "Backend not running"
fi
echo ""

# Stop nginx
echo "Stopping nginx..."
if pgrep nginx > /dev/null; then
    sudo nginx -s stop && echo "✓ nginx stopped" || echo "Failed to stop nginx"
else
    echo "nginx not running"
fi
echo ""

echo "Application stopped"

