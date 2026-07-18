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
- `PUT /api/transactions/<id>` - Update a transaction
- `DELETE /api/transactions/<id>` - Delete a transaction
- `POST /api/upload` - Upload and scan a receipt image
- `GET /api/categories` - Get available categories
- `POST /api/categories` - Add a category
- `PUT /api/categories/<name>` - Rename a category (cascades to transactions)
- `DELETE /api/categories/<name>` - Delete a category
- `GET /api/accounts` - Get all accounts with balances
- `POST /api/accounts` - Add a new account
- `PUT /api/accounts/<id>` - Update an account
- `DELETE /api/accounts/<id>` - Delete an account
- `GET /api/subscriptions` - Get all subscriptions
- `POST /api/subscriptions` - Add a new subscription
- `PUT /api/subscriptions/<id>` - Update a subscription
- `DELETE /api/subscriptions/<id>` - Delete a subscription
- `POST /api/subscriptions/check` - Record any subscription charges due this month

## Troubleshooting

### Connection Refused Errors

If you see `ERR_CONNECTION_REFUSED` in the browser console:
1. Make sure the backend server is running
2. Check that it's running on port 5001
3. Verify with: `curl http://localhost:5001/api/categories`

### Waitress vs Flask Development Server

**Use Waitress when:**
- Running in production
- Need better performance
- Want a stable, multi-threaded server

**Use Flask development server when:**
- Debugging code
- Need auto-reload on code changes
- Development environment only
