#!/bin/bash

# ReceiptOCR Deployment Script
# This script builds the frontend and sets up nginx configuration

set -e  # Exit on error

echo "======================================"
echo "ReceiptOCR Deployment Script"
echo "======================================"
echo ""

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo ""

# Build frontend
echo "Step 1: Building frontend..."
cd "$PROJECT_ROOT/frontend"
npm run build

if [ ! -d "dist" ]; then
    echo "Error: Frontend build failed - dist directory not found"
    exit 1
fi
echo "✓ Frontend built successfully"
echo ""

# Check if nginx is installed
echo "Step 2: Checking nginx installation..."
if ! command -v nginx &> /dev/null; then
    echo "Error: nginx is not installed"
    echo "Install with: brew install nginx"
    exit 1
fi
echo "✓ nginx is installed"
echo ""

# Copy nginx configuration
echo "Step 3: Setting up nginx configuration..."
if [ -d "/opt/homebrew/etc/nginx" ]; then
    NGINX_CONF_DIR="/opt/homebrew/etc/nginx/servers"
else
    NGINX_CONF_DIR="/usr/local/etc/nginx/servers"
fi

if [ ! -d "$NGINX_CONF_DIR" ]; then
    echo "Creating nginx servers directory at $NGINX_CONF_DIR..."
    sudo mkdir -p "$NGINX_CONF_DIR"
fi

sudo cp "$PROJECT_ROOT/deployment/nginx.conf" "$NGINX_CONF_DIR/receiptocr.conf"
echo "✓ nginx configuration copied to $NGINX_CONF_DIR/receiptocr.conf"
echo ""

# Test nginx configuration
echo "Step 4: Testing nginx configuration..."
sudo nginx -t
echo ""

# Reload nginx
echo "Step 5: Reloading nginx..."
if pgrep -x nginx > /dev/null; then
    sudo nginx -s reload
    echo "✓ nginx reloaded"
else
    echo "Starting nginx..."
    sudo nginx
    echo "✓ nginx started"
fi
echo ""

echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Start the backend: cd backend && python3 run_waitress.py"
echo "2. Get your Tailscale IP: tailscale ip -4"
echo "3. Access the app: http://<tailscale-ip>"
echo ""
