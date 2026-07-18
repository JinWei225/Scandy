#!/bin/bash

# Get Tailscale IP - works with any Tailscale installation
get_tailscale_ip() {
    # Try common locations
    if [ -f "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
        /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null
    elif command -v tailscale &> /dev/null; then
        tailscale ip -4 2>/dev/null
    else
        echo "Tailscale not found"
        return 1
    fi
}

echo "======================================"
echo "Scandy - Tailscale IP Address"
echo "======================================"
echo ""

TAILSCALE_IP=$(get_tailscale_ip)

if [ $? -eq 0 ] && [ ! -z "$TAILSCALE_IP" ]; then
    echo "✓ Tailscale IP: $TAILSCALE_IP"
    echo ""
    echo "Access from your devices:"
    echo "  📱 Phone: http://$TAILSCALE_IP"
    echo "  💻 Computer: http://localhost"
else
    echo "⚠️  Could not get Tailscale IP"
    echo ""
    echo "Make sure Tailscale is running:"
    echo "  - Open Tailscale app"
    echo "  - Ensure you're connected"
    echo ""
    echo "Local access: http://localhost"
fi
echo ""
