#!/usr/bin/env python3
"""
Production server startup script using Waitress WSGI server.
Run this instead of app.py for production deployments.
"""
import signal
import sys

from waitress import serve

from app import app
from ocr import OCR_BACKEND, shutdown_ocr


def _terminate(signum, _frame):
    """Stop the OCR backend before exiting.

    Python's default SIGTERM handling exits without running atexit handlers, and
    SIGTERM is exactly what deployment/stop.sh sends. Without this the extraction
    model is orphaned and keeps its memory until the machine is rebooted.
    """
    print(f"\nReceived signal {signum}, shutting down...")
    shutdown_ocr()
    sys.exit(0)


if __name__ == '__main__':
    print("=" * 60)
    print("Starting Scandy Backend with Waitress WSGI Server")
    print("=" * 60)
    print(f"Server running at: http://0.0.0.0:5001")
    print(f"API endpoints available at: http://0.0.0.0:5001/api/")
    print(f"OCR backend: {OCR_BACKEND}")
    print("Accessible from all interfaces (localhost + Tailscale)")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)

    signal.signal(signal.SIGTERM, _terminate)
    signal.signal(signal.SIGINT, _terminate)

    # Start Waitress server
    # host='0.0.0.0' allows external connections (nginx, Tailscale)
    try:
        serve(app, host='0.0.0.0', port=5001, threads=4)
    finally:
        shutdown_ocr()
