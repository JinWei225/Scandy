# Scandy - Deployment Scripts

This directory contains scripts for deploying and managing the Scandy application with nginx and Tailscale support.

## Files

- **`nginx.conf`** - Nginx reverse proxy configuration
- **`deploy.sh`** - One-time deployment setup script
- **`start.sh`** - Start the backend server
- **`stop.sh`** - Stop backend and nginx
- **`get-ip.sh`** - Get your Tailscale IP address
- **`README.md`** - This file

## Quick Start

### First Time Setup

```bash
# Run deployment script
./deployment/deploy.sh
```

This builds the frontend and configures nginx.

### Daily Usage

**Start backend:**
```bash
./deployment/start.sh
```

**Get your Tailscale IP:**
```bash
./deployment/get-ip.sh
```

**Stop everything:**
```bash
./deployment/stop.sh
```

## Accessing the App

**From Computer:** http://localhost

**From Phone:**
1. Run `./deployment/get-ip.sh` to get your Tailscale IP
2. Open that IP in your phone's browser

## Manual Commands

### Backend Only
```bash
cd backend
python3 run_waitress.py
```

### Nginx
```bash
# Start
sudo nginx

# Reload
sudo nginx -s reload

# Stop  
sudo nginx -s stop
```

### Build Frontend
```bash
cd frontend
npm run build
sudo nginx -s reload
```

## Troubleshooting

**"Address already in use"**
```bash
./deployment/stop.sh
./deployment/start.sh
```

**Check what's on port 5001:**
```bash
lsof -i :5001
```

**Nginx errors:**
```bash
sudo nginx -t  # Test config
tail -f /usr/local/var/log/nginx/error.log
```

**Can't get Tailscale IP:**
- Make sure Tailscale app is running
- Check you're connected in the Tailscale menu
