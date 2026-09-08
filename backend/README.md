# Scandy Backend

This is the backend server for the Scandy application, built with Flask.

## Requirements

Dependencies are declared in the project root's `pyproject.toml` and pinned by `uv.lock`.
From the project root:

```bash
uv sync
```

`requirements.txt` in this directory is a **generated** pinned export of `uv.lock`, kept
for environments without uv. Do not edit it by hand — regenerate it from the project root:

```bash
uv export --no-dev --no-hashes --no-emit-project -o backend/requirements.txt
```

## Receipt Scanning

`POST /api/upload` returns `{"date": "DD/MM/YYYY", "time": "HH:MM:SS", "amount": "RM 12.50"}`.
Which engine produces that is chosen by the `OCR_BACKEND` environment variable:

| `OCR_BACKEND` | Pipeline | Platform |
| --- | --- | --- |
| `vision` *(default)* | Apple Vision OCR → NuExtract-1.5-tiny (0.5B, Q4) via `llama.cpp` | macOS |
| `ollama` | Vision model on an Ollama server, reading the image directly | Anywhere (used by Docker) |

### How the `vision` backend works

```
image → downscale to 1600px → Apple Vision → row-grouped text → NuExtract → parse in Python
```

1. **`ocr/vision_backend.py`** caps the longest edge at 1600px and hands the image to
   Apple's Vision framework. Vision ships with macOS, so it costs nothing on disk and
   holds no memory of its own.
2. **`ocr/receipt_text.py:assemble_text`** sorts the detections top-to-bottom and rejoins
   same-row ones with a tab. Receipts are label/value pairs in columns, and flattening
   the detections in detector order destroys that pairing — nothing downstream can
   recover it.
3. **NuExtract** is given the text and a JSON template whose empty strings define the
   schema, with a GBNF grammar constraining the output. It only ever copies spans; it is
   never asked to reformat, because at 0.5B it gets reformatting wrong.
4. **`ocr/receipt_text.py:build_result`** does the parsing — 12-hour AM/PM resolution,
   day-first dates, `Decimal` for money, and range checks. A field that fails validation
   comes back as `None` rather than as a guess.

A field the model missed entirely falls back to `amount_from_text`, which recovers the
total from the OCR text. That fallback is *guarded*: it prefers lines labelled as a
total and discards lines labelled as a balance, change, cash tendered or points. A plain
"largest number on the receipt" rule scores 2/9 on receipts that also show an account
balance; the guarded rule scores 9/9.

### Configuration

Tuning lives in plain constants at the top of `ocr/vision_backend.py` — the model repo,
context size, image cap, OCR languages, and the amount-fallback mode. Each carries the
reasoning for its value; change them there rather than through the environment.

### Prerequisites

`llama-server` must be on `PATH` (`brew install llama.cpp`). The backend starts one
lazily on the first scan and keeps it alive; the ~491 MB of weights download themselves
on first use into `~/.cache/huggingface`.

The process is stopped on `SIGTERM`/`SIGINT` by `run_waitress.py`, and its PID is written
to `backend/llama-server.pid` so `deployment/stop.sh` can reap it if the backend is ever
killed harder than that.

### Benchmarking

`bench/compare_pipelines.py` compares this pipeline against the MLX-VLM one it replaced,
measuring resident memory, peak memory, disk, latency and per-field accuracy. It needs
the optional `bench` dependency group:

```bash
uv sync --group bench
.venv/bin/python backend/bench/compare_pipelines.py --arms all
.venv/bin/python backend/bench/compare_pipelines.py --probe-amount-fallback
```

Add receipts to `backend/img/` and label them in `bench/ground_truth.json` to widen the
accuracy sample.

## Running the Server

### Option 1: Production Server with Waitress (Recommended)

Waitress is a production-ready WSGI server that is more stable and performant than Flask's development server.

```bash
python3 run_waitress.py
```

**Features:**
- Production-ready WSGI server
- Better performance and stability
- Multi-threaded (4 threads by default)
- No development server warnings

### Option 2: Development Server with Flask

For development and debugging only:

```bash
python3 app.py
```

**Note:** This will show a warning that it's not suitable for production use.

## Server Information

- **Port:** 5001
- **Host:** localhost (127.0.0.1)
- **Base URL:** http://localhost:5001
- **API Endpoints:** http://localhost:5001/api/

## Available Endpoints

- `GET /api/transactions` - Get all transactions
- `POST /api/transactions/manual` - Add a manual transaction
- `POST /api/transactions/transfer` - Create a transfer between two accounts
- `PUT /api/transactions/<id>` - Update a transaction
- `DELETE /api/transactions/<id>` - Delete a transaction
- `POST /api/upload` - Upload and scan a receipt image (see [Receipt Scanning](#receipt-scanning))
- `GET /api/categories` - Get available categories
- `POST /api/categories` - Add a category (body: `type`, `name`)
- `PUT /api/categories` - Rename a category (body: `type`, `old_name`, `new_name`) — cascades to transactions
- `DELETE /api/categories` - Delete a category (body: `type`, `name`)
- `GET /api/accounts` - Get all accounts with balances
- `POST /api/accounts` - Add a new account
- `PUT /api/accounts/<id>` - Update an account
- `DELETE /api/accounts/<id>` - Delete an account
- `GET /api/subscriptions` - Get all subscriptions
- `POST /api/subscriptions` - Add a new subscription
- `PUT /api/subscriptions/<id>` - Update a subscription
- `DELETE /api/subscriptions/<id>` - Delete a subscription
- `POST /api/subscriptions/check` - Record any subscription charges due this month
- `POST /api/logs` - Sink for client-side logs

## Troubleshooting

### Connection Refused Errors

If you see `ERR_CONNECTION_REFUSED` in the browser console:
1. Make sure the backend server is running
2. Check that it's running on port 5001
3. Verify with: `curl http://localhost:5001/api/categories`

### Receipt Scanning Fails

| Message | Cause |
| --- | --- |
| `llama-server is not on PATH` | Install it: `brew install llama.cpp` |
| `Could not download ... .gguf` | No network on first run. Set `LLM_GGUF_PATH` in `ocr/vision_backend.py` to a local file instead |
| `The Apple Vision bindings are not installed` | Run `uv sync` from the project root |
| `Another scan is in progress` (HTTP 429) | Scans are serialised by design; retry |

### Waitress vs Flask Development Server

**Use Waitress when:**
- Running in production
- Need better performance
- Want a stable, multi-threaded server

**Use Flask development server when:**
- Debugging code
- Need auto-reload on code changes
- Development environment only
