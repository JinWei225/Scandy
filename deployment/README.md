# Scandy — Native Deployment Scripts

Scripts for running Scandy directly on your machine (nginx + Waitress), as an
alternative to the Docker stack in the repository root.

Use these if you are on an Apple Silicon Mac and want MLX-VLM receipt scanning
on the GPU. Everyone else is better served by `docker compose up -d` — see the
main [README](../README.md).

## Files

| File | Purpose |
| --- | --- |
| `deploy.sh` | One-time setup: builds the frontend and installs the nginx config |
| `start.sh` | Start the backend |
| `stop.sh` | Stop the backend |
| `status.sh` | Show what is running |
| `get-ip.sh` | Print your Tailscale IP for phone access |
| `common.sh` | Shared helpers (sourced by the others, not run directly) |
| `nginx.conf.template` | nginx site config; `deploy.sh` fills in your project path |

## Quick start

```bash
./deployment/deploy.sh    # build frontend + configure nginx (asks for sudo)
./deployment/start.sh     # start the API
./deployment/status.sh    # confirm it is up
```

Then open <http://localhost>.

## Daily use

```bash
./deployment/start.sh              # start in the background
./deployment/start.sh --foreground # run in this terminal instead (Ctrl+C stops it)
./deployment/stop.sh               # stop
./deployment/status.sh             # check state
tail -f backend/waitress.log       # follow the log
```

Every script accepts `--help`.

After pulling new code, re-run `./deployment/deploy.sh` to rebuild the frontend.

## What the scripts check for you

`start.sh` refuses to launch and tells you what to fix when:

- the Python environment is missing or lacks Flask/Waitress (`uv sync`)
- port 5001 is already taken — including the case where something is holding the
  port but not answering requests
- the server exits during startup — the last 20 log lines are printed instead of
  leaving you with a silent failure

It waits for the API to actually respond before reporting success, so "started"
means the app is serving requests, not merely that a process was spawned.

`stop.sh` sends `SIGTERM` first so in-flight requests and open SQLite
transactions finish cleanly, and only escalates to `SIGKILL` after 10 seconds.

> **nginx is not stopped by default.** It is a system-wide service that may be
> serving other sites. Use `./deployment/stop.sh --nginx` if you want it stopped
> too.

## nginx notes

`deploy.sh` generates the site config from `nginx.conf.template`, substituting
the real path to `frontend/dist`. Do not edit the installed `scandy.conf`
directly — edit the template and re-run `deploy.sh`.

The config is installed into your nginx `servers/` (or `conf.d/`) directory.
That only takes effect if your main `nginx.conf` includes it:

```nginx
http {
    include /opt/homebrew/etc/nginx/servers/*.conf;
}
```

`deploy.sh` checks for this and warns you if it is missing — otherwise nginx
silently ignores the file and the site never loads.

## Phone access

```bash
./deployment/get-ip.sh
```

Open the printed Tailscale IP in your phone's browser. Tailscale must be running
and connected on both devices.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Port 5001 is in use ... but the API is not responding` | Something else holds the port: `lsof -i :5001`, then `./deployment/stop.sh` |
| `Backend dependencies are missing` | `uv sync` from the project root |
| Browser shows 404 or a blank page | The frontend is not built: `./deployment/deploy.sh` |
| Changes to the app do not appear | Rebuild: `./deployment/deploy.sh`, then hard-refresh |
| `nginx: [emerg] invalid number of arguments in "root"` | An old hand-edited config with an unquoted path containing spaces. Re-run `./deployment/deploy.sh` |
| nginx runs but the site 404s | Your `nginx.conf` may not include the servers directory — see nginx notes above |
| API works on `:5001` but not port 80 | nginx is not running: `sudo nginx` |
