#!/usr/bin/env python3
"""
Production server startup script using Waitress WSGI server.
Run this instead of app.py for production deployments.
"""
from waitress import serve
from app import app

if __name__ == '__main__':
    print("=" * 60)
    print("Starting ReceiptOCR Backend with Waitress WSGI Server")
    print("=" * 60)
    print(f"Server running at: http://0.0.0.0:5001")
    print(f"API endpoints available at: http://0.0.0.0:5001/api/")
    print("Accessible from all interfaces (localhost + Tailscale)")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)
    
    # Start Waitress server
    # host='0.0.0.0' allows external connections (nginx, Tailscale)
    serve(app, host='0.0.0.0', port=5001, threads=4)

