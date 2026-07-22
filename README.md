# 🧾 Scandy

Scandy is a sleek, modern, full-stack receipt scanner and personal transaction manager. Built to be local-first, it runs a local Vision-Language Model (VLM) — via **MLX-VLM** on Apple Silicon, or **Ollama** anywhere else — to analyze receipt images, extract transaction details, and automatically categorize them. No data leaves your machine.

Want to self-host it? [**Jump to the Docker setup →**](#-docker-self-hosting)

The application features a responsive Vue.js dashboard — with light and dark themes — to manage transactions, review category-wise expenses, manage recurring subscriptions, and monitor account balances.

---

## ✨ Features

- **Local AI OCR Receipt Scanning:** Upload receipt images (`.jpg`, `.png`, etc.) to automatically extract:
  - Merchant Name
  - Transaction Date & Time
  - Line Items & Prices
  - Tax & Total Amount
  - Suggested Expense Category
- **Manual Transaction Logging:** Quickly log expenses with custom details, accounts, and types (expense vs. income).
- **Account Transfers:** Move money between accounts as a paired transaction.
- **Category-Wise Summaries:** Monthly breakdowns per category, with a drill-down into the transactions behind each one.
- **Custom Categories:** Add, rename, and delete expense/income categories from Settings. Renames cascade to existing transactions and subscriptions.
- **Subscription Tracker:** Track recurring subscriptions with monthly cost summaries. Charges due in the current month are recorded automatically on app start.
- **Multi-Account Balance Management:** Monitor balances across multiple accounts (e.g., Cash, Credit Cards, Bank Accounts), with a per-account transaction history.
- **Search:** Full-text search across logged transactions.
- **Light & Dark Themes:** Toggle from Settings; the choice is persisted.
- **Navigation Bar:** Top navigation on desktop, bottom navigation bar on mobile.
- **Capacitor Mobile Wrapper:** Built-in Android configuration, including share-to-Scandy support so a receipt image can be shared from any app straight into the transaction form.

---

## 🛠️ Technology Stack

### Backend
- **Python / Flask:** Web API server
- **Pluggable local OCR engine** (no remote API keys required!), selected with `OCR_BACKEND`:
  - `mlx` *(default)* — **MLX-VLM** on Apple Silicon, `mlx-community/Qwen3.5-0.8B-4bit`
  - `ollama` — a vision model on an **Ollama** server, used by the Docker stack so it runs on any platform
- **SQLite:** Local-first relational database storage for transactions
- **JSON files:** Accounts, subscriptions, and categories (`backend/accounts.json`, `subscriptions.json`, `categories.json`)
- **Waitress:** Production-ready multi-threaded WSGI server
- **Pillow:** Image preprocessing

### Frontend
- **Vue 3 + Vue Router:** Reactive single-page application
- **Tailwind CSS:** Design-token-driven styling with light/dark theming
- **Material Symbols / Fontsource:** Icons and typography
- **Axios:** API client
- **Capacitor:** Cross-platform native wrapper (runs on Web, Android, etc.)

---

## 🚀 Setup & Installation

There are two ways to run Scandy — pick one:

| | [🐳 Docker](#-docker-self-hosting) | [💻 Native](#-native-setup-apple-silicon) |
| --- | --- | --- |
| **Platform** | Linux, Windows, macOS (any CPU) | Apple Silicon Mac only |
| **Setup** | One command | Python + Node + nginx by hand |
| **OCR engine** | Ollama (containerized) | MLX-VLM (Metal-accelerated) |
| **Scan speed** | Slower | Fastest |
| **Best for** | Self-hosting on your own machine | Getting maximum speed when self-hosting on a Mac |

---

## 🐳 Docker (Self-Hosting)

The easiest way to run Scandy on your own machine. Everything — web app, API, and the
vision model that reads receipts — runs in containers, so there is nothing to install
besides Docker.

> **Why a different OCR engine?** The native setup uses Apple's MLX, which requires
> Metal and therefore cannot run inside a container. The Docker stack uses
> [Ollama](https://ollama.com/) instead, which runs anywhere. It runs
> `qwen3.5:0.8b` — the same model family as the native setup — with the same prompt
> and the same output format.

### Prerequisites
- **[Docker](https://docs.docker.com/get-docker/)** with Compose v2 (included in Docker Desktop)
- **Disk space:** ~1.3 GB if you already run Ollama, or ~5.5 GB with the bundled one
  (Ollama runtime image ≈4.2 GB, model ≈1 GB, Scandy images ≈240 MB)
- 4 GB RAM recommended

### Quick Start

```bash
git clone <your-repo-url> Scandy
cd Scandy
cp .env.example .env
docker compose up -d
```

Then open **http://localhost:8080**.

That's it. The app is usable straight away with an empty database and a default set of
categories. In the background, the `ollama-pull` service downloads the ~1 GB model —
until it finishes, manual transaction entry works normally and receipt scanning returns
a "model not pulled yet" message.

Watch the download progress with:

```bash
docker compose logs -f ollama-pull
```

> **Don't skip `cp .env.example .env`.** It sets `COMPOSE_PROFILES=bundled`, which is
> what starts the bundled Ollama. Without it you'd need `--profile bundled` on *every*
> command — including `down`, or the Ollama container gets left running.

---

### Reuse an Ollama You Already Have

If you already run Ollama — installed on your computer, or in another container — you
don't need a second copy. Edit `.env`, remove the `COMPOSE_PROFILES=bundled` line, and
point Scandy at it:

```bash
OLLAMA_HOST=http://host.docker.internal:11434
```

Then `docker compose up -d` starts only the web app and API — no Ollama image is
downloaded and no second model copy is stored.

| Your setup | `OLLAMA_HOST` |
| --- | --- |
| Ollama installed on this computer | `http://host.docker.internal:11434` |
| Ollama container with port 11434 published | `http://host.docker.internal:11434` |
| Ollama on another machine / NAS | `http://<your-machine-ip-address>:11434` |

Pull the model once into your own Ollama:

```bash
ollama pull qwen3.5:0.8b
```

> **A host install must listen on `0.0.0.0`.** By default Ollama binds only to
> `127.0.0.1`, which containers cannot reach — scans then fail with "Could not reach
> Ollama". Fix it per platform:
> - **macOS:** `launchctl setenv OLLAMA_HOST 0.0.0.0` then restart Ollama
> - **Linux:** `systemctl edit ollama` → add `Environment="OLLAMA_HOST=0.0.0.0"`, then `systemctl restart ollama`
> - **Windows:** set an `OLLAMA_HOST=0.0.0.0` user environment variable, then restart Ollama
>
> `host.docker.internal` is wired up on Linux too (via `extra_hosts` in `compose.yaml`),
> so the same value works on every platform.

**Advanced — joining an existing container network.** If your Ollama runs in another
compose stack and you'd rather not publish its port, attach Scandy to that network and
use the container name directly, e.g. `OLLAMA_HOST=http://ollama:11434`, adding to
`compose.yaml`:

```yaml
services:
  backend:
    networks: [default, ollama-net]
networks:
  ollama-net:
    external: true
    name: <the-other-stack>_default
```

---

### Configuration

All settings live in `.env` and have working defaults.

| Variable | Default | Purpose |
| --- | --- | --- |
| `COMPOSE_PROFILES` | `bundled` | Set to `bundled` to run Ollama in this stack; remove to use your own |
| `OLLAMA_HOST` | `http://ollama:11434` | Your Ollama address, when not using the bundled one |
| `SCANDY_PORT` | `8080` | Host port the web app is served on |
| `OLLAMA_MODEL` | `qwen3.5:0.8b` | Model used for scanning |
| `OLLAMA_NUM_CTX` | `8192` | Model context window (an image costs thousands of tokens) |
| `OLLAMA_MAX_IMAGE_EDGE` | `1280` | Longest image edge sent to the model |

### A Note on Scan Accuracy

`qwen3.5:0.8b` is the same model family the native MLX setup uses, so results are
comparable. On the bundled test receipt it reads the date, time and total correctly in
**5–9 seconds** on CPU.

If a date can't be read from a receipt, Scandy falls back to the current date and time,
and you confirm or correct the values in the UI before saving — so a partial reading is
never a failed scan.

Raising `OLLAMA_MAX_IMAGE_EDGE` is generally *not* worth it: in testing, full-resolution
images made scans several times slower with no accuracy gain.

### Your Data

Everything lives in the `scandy-data` Docker volume — the SQLite database, accounts,
subscriptions, and categories. It persists across restarts and image rebuilds.

```bash
# Back up
docker run --rm -v scandy-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/scandy-backup.tar.gz -C /data .

# Wipe everything and start fresh
docker compose down -v
```

### Common Commands

```bash
docker compose logs -f          # follow logs
docker compose restart backend  # restart just the API
docker compose down             # stop (data is kept)
docker compose up -d --build    # update after pulling new code
```

These all read `.env`, so they cover the bundled Ollama too. If you chose not to create
a `.env`, add `--profile bundled` to each of them — otherwise `down` leaves the Ollama
container running.

### Accessing From Your Phone

The containers listen on all interfaces, so replace `localhost` with your machine's LAN
or [Tailscale](https://tailscale.com/) IP — e.g. `http://192.168.1.20:8080`.

### Troubleshooting

| Symptom | Fix |
| --- | --- |
| Scanning returns "does not have the model" | The pull is still running or failed. Check `docker compose logs ollama-pull`, or pull manually: `docker compose exec ollama ollama pull qwen3.5:0.8b` |
| "Could not reach Ollama … start it with --profile bundled" | You have no `.env`, so the bundled Ollama never started. Run `cp .env.example .env` and `docker compose up -d` |
| "Could not reach Ollama" with your own Ollama | It's probably bound to `127.0.0.1`. See [Reuse an Ollama You Already Have](#reuse-an-ollama-you-already-have) |
| Ollama still running after `docker compose down` | Profile services need the profile. Use a `.env`, or `docker compose --profile bundled down` |
| `docker pull` hangs at "load metadata" | Docker is waiting on a credential prompt. On macOS this can be a keychain password dialog behind another window; run `docker pull python:3.13-slim` in a terminal to answer it |
| Scans are slow or time out | Expected on CPU. Give Docker more RAM, or lower `OLLAMA_MAX_IMAGE_EDGE` |
| Port 8080 already in use | Set `SCANDY_PORT` in `.env` |

---

## 💻 Native Setup (Apple Silicon)

The fastest option, and the one used for development. Runs MLX-VLM directly on the GPU.

### Prerequisites
- **Python 3.13+**
- **Node.js 18+** & **npm**
- **[uv](https://docs.astral.sh/uv/)** (recommended) — manages the Python environment
- **nginx** (`brew install nginx`) — serves the frontend and proxies the API
- Apple Silicon Mac — receipt extraction runs locally via MLX

---

### Quick Start

If you just want it running, these three commands do everything:

```bash
uv sync                   # install Python dependencies
./deployment/deploy.sh    # build the frontend and configure nginx (asks for sudo)
./deployment/start.sh     # start the backend
```

Then open <http://localhost>. Check on it any time with `./deployment/status.sh`,
and stop it with `./deployment/stop.sh`.

The sections below explain each part if you would rather do it by hand, or need
to troubleshoot.

---

### 1. Backend Setup

`pyproject.toml` + `uv.lock` are the source of truth for Python dependencies.

```bash
# From the project root — creates .venv and installs the locked dependencies
uv sync
```

<details>
<summary>Alternative: plain pip</summary>

`backend/requirements.txt` is a **generated** pinned export of `uv.lock`, kept for
environments without uv. Regenerate it whenever `pyproject.toml` or `uv.lock` changes:

```bash
uv export --no-dev --no-hashes --no-emit-project -o backend/requirements.txt
```

To install from it:

```bash
pip install -r backend/requirements.txt
```
</details>

#### Running the Backend

##### Option A: Managed script (Recommended)
Starts Waitress in the background with preflight checks and a real health check —
see [Managing the Server](#4-managing-the-server) below.
```bash
./deployment/start.sh
```

##### Option B: Run Waitress directly
Waitress is a production-ready WSGI server that is multi-threaded, highly performant, and stable.
```bash
cd backend
python run_waitress.py
```

##### Option C: Development Server with Flask
Use this only for local debugging (features auto-reload):
```bash
cd backend
python app.py
```

- **Port:** `5001`
- **Base URL:** `http://localhost:5001`
- **API Endpoints:** `http://localhost:5001/api/`

---

### 2. Frontend Setup

```bash
# Navigate to frontend directory
cd frontend

# Install Node dependencies
npm install
```

#### Running the Frontend

##### Compiles and Hot-Reloads for Development
```bash
npm run serve
```
The application will be accessible in your browser at `http://localhost:8080`.

##### Compiles and Minifies for Production
```bash
npm run build
```

##### Lints and Fixes Files
```bash
npm run lint
```

---

### 3. Serving It (nginx)

`npm run serve` is for development only. To actually host the app — and to reach
it from your phone — nginx serves the built frontend on port 80 and forwards
`/api/` to the backend on port 5001.

```bash
./deployment/deploy.sh
```

This builds `frontend/dist`, generates the nginx site config from
`deployment/nginx.conf.template` with your project's real path, validates it with
`nginx -t`, and reloads nginx.

> The config is installed into nginx's `servers/` directory, which only takes
> effect if your main `nginx.conf` contains `include .../servers/*.conf;` inside
> its `http { }` block. Stock installs have it; a hand-edited `nginx.conf` often
> does not. `deploy.sh` checks and tells you if it is missing — without that
> line, nginx ignores the config and the site never loads.

Re-run `./deployment/deploy.sh` after pulling new code to rebuild the frontend.

---

### 4. Managing the Server

| Command | What it does |
| --- | --- |
| `./deployment/start.sh` | Start the backend in the background, logging to `backend/waitress.log` |
| `./deployment/start.sh --foreground` | Run it in the current terminal instead (Ctrl+C stops it) |
| `./deployment/stop.sh` | Stop the backend gracefully |
| `./deployment/stop.sh --nginx` | Also stop nginx |
| `./deployment/status.sh` | Show what is running; exits non-zero if the API is down |
| `./deployment/get-ip.sh` | Print your Tailscale IP for phone access |

All of them accept `--help`.

These scripts exist so failures are actionable rather than silent. `start.sh`
verifies the Python environment, refuses to start a second copy on an occupied
port, and then **waits until the API actually answers a request** before
reporting success — if the server dies during startup it prints the last 20 log
lines instead of leaving you to guess. `stop.sh` sends `SIGTERM` first so
in-flight requests and open SQLite transactions finish cleanly, escalating to
`SIGKILL` only after 10 seconds, then confirms the port was released.

That last part matters: stopping the server with Ctrl+C can leave port 5001 held,
which makes the next start fail with *"Address already in use."* Running
`./deployment/stop.sh` clears it properly.

**Restarting:**
```bash
./deployment/stop.sh && ./deployment/start.sh
```

**Accessing from your phone:** run `./deployment/get-ip.sh` and open the printed
Tailscale IP in your phone's browser. Tailscale must be connected on both devices.

See [deployment/README.md](deployment/README.md) for a troubleshooting table.

---

## 🗺️ App Routes

| Route | Page |
| --- | --- |
| `/` | Home — log a transaction, current month overview |
| `/all` | Summary — all transactions and category breakdowns |
| `/accounts` | Vault — accounts and balances |
| `/accounts/:id` | Transactions for a single account |
| `/subscriptions` | Recurring — subscription tracker |
| `/settings` | Settings — theme and category management |

---

## 🔌 API Endpoints Reference

### Transactions
- `GET /api/transactions` - Retrieve all transactions
- `POST /api/transactions/manual` - Add a manual transaction
- `POST /api/transactions/transfer` - Create a transfer between two accounts
- `PUT /api/transactions/<id>` - Update an existing transaction
- `DELETE /api/transactions/<id>` - Delete a transaction
- `POST /api/upload` - Upload a receipt image and process it via local VLM

### Categories
- `GET /api/categories` - Retrieve expense and income categories
- `POST /api/categories` - Add a category (body: `type`, `name`)
- `PUT /api/categories` - Rename a category (body: `type`, `old_name`, `new_name`) — cascades to transactions
- `DELETE /api/categories` - Delete a category (body: `type`, `name`)

### Accounts
- `GET /api/accounts` - Retrieve all accounts and balances
- `POST /api/accounts` - Create a new account
- `PUT /api/accounts/<id>` - Update account details
- `DELETE /api/accounts/<id>` - Delete an account

### Subscriptions
- `GET /api/subscriptions` - Retrieve all subscriptions
- `POST /api/subscriptions` - Add a recurring subscription
- `PUT /api/subscriptions/<id>` - Update subscription details
- `DELETE /api/subscriptions/<id>` - Delete a subscription
- `POST /api/subscriptions/check` - Record any subscription charges due this month

### Misc
- `POST /api/logs` - Sink for client-side logs (useful when debugging the mobile build)
