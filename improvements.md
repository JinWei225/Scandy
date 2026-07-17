# Scandy — Code Audit & Improvement Plan

Audit date: 2026-07-17. Reference notes for future fixes. File/line refs are from the state of the repo at commit `dda8960`.

## Status update — 2026-07-17 (post-fix pass)

**Done in this pass:**
- §1 bugs **1.1–1.13 all fixed** (1.14 deferred by choice — missed months are still not backfilled).
- §2 dead code removed: budget feature (endpoints + functions + budgets.json), `InfoExtractionMLX.py`, root `main.py`, root `package.json`/`node_modules`, `git_backups/`, chart.js/vue-chartjs, `json_date_converter`, commented favicon route, `totalBalance` dead state, `ollama` dep. **`torch`/`torchvision` had to stay** — transformers' Qwen3-VL processor needs torchvision at model-load time (verified: removal breaks OCR). Removed files are in `~/.Trash/scandy-cleanup/`.
- **Kept intentionally:** `ThemeSwitcher.vue` / `themeStore.js` — user wants light mode back later. `.env.production` still unwired (part of 3.1, not done).

**Still open:** everything in §3 (stability/deployment), §4 (structure/duplication), §5 (efficiency), §6 (features), and bug 1.14.

## Status update — 2026-07-17 (second pass: structure, hardening, theme)

**Done in this pass:**
- **3.1** — Native API URL now comes from `frontend/.env.production` (`VUE_APP_NATIVE_API_URL`), with the old IP as fallback in App.vue.
- **3.2** — Tailwind CDN and Google-Fonts links removed; Tailwind v3 is now a build dependency (`tailwind.config.js`, `postcss.config.js`, `src/assets/main.css`), fonts self-hosted via @fontsource (latin subsets) and `material-symbols`. App styles/icons now work fully offline.
- **3.3** — API 500s no longer leak `str(e)`; tracebacks go to the server log, clients get generic messages (ValueError→400 keeps its message).
- **3.4** — `/api/logs` whitelists level, caps message/context length, strips escape chars; `logger.js` only posts remotely on native.
- **3.5** — OCR rejects concurrent scans with 429 (`OCRBusyError`, non-blocking lock acquire) instead of silently tying up threads.
- **3.6** — Scans missing date/time no longer fail; they default to now and the user confirms in the modal (amount still required).
- **4.3 (amounts)** — API now returns `amount_cents` (int) alongside the display string on every transaction response; all frontend math uses cents, `parseFloat(replace('RM'))` parsing eliminated from computeds. (ISO-date part of 4.3 still open, see 4.8.)
- **4.1** — `useMonthlyFilter` composable + `CategorySummaryList` component replace the duplicated summary logic in AllTransactions/AccountTransactions (~350 lines removed).
- **4.2** — `EditModal` + `ConfirmationModal` merged into `TransactionFormModal` (title/submitLabel props).
- **4.4** — `useAccounts` singleton composable; all views use it; `useTransactionModals` centralizes edit/delete/detail plumbing; SearchModal/AccountsPage/SubscriptionsPage now use `ConfirmDeleteModal` (no more browser `confirm()`).
- **4.6** — Account routes use `/accounts/:id` instead of `:name`.
- **4.7** — `SendIntent` plugin registered once in `useIntent.js`.
- **§5** — `get_account_balances` uses one SQL GROUP BY; App.vue no longer double-fetches transactions on mount; hardcoded `#34d399` income green replaced by a themed `income` token.
- **Theme system rebuilt** — palettes live as CSS variables in `src/assets/main.css` (`:root` dark default, `html.light` overrides), Tailwind colors point at the vars with alpha support. `ThemeSwitcher` restored in the header (Material Symbols sun/moon), `themeStore` defaults to dark, `index.html` applies the saved theme pre-mount. Light palette = M3 light scheme for the same orange seed, keeping #ff6b00 as accent. Screenshot comparison: https://claude.ai/code/artifact/0e222de1-24f9-4689-b742-8251155f45b4

**Still open:** 1.14 (subscription backfill), 3.7 (requirements.txt is still the legacy non-pinned list), 3.8 (no automated tests), 4.5 fully (AccountsPage/SubscriptionsPage still inline their add/edit modal markup; BaseModal only used by CategoryDetailModal), 4.8 (DB still stores DD/MM/YYYY + per-request Python sorting; needs a data migration), §6 features. Optional: subset the 3.9 MB Material Symbols variable font to only the ~22 icons used.

---

## 1. Bugs / Correctness (fix first)

### 1.1 Deleting one leg of a transfer orphans the other leg — **data corruption**
`backend/main.py:306` — `delete_transaction_by_id` deletes only the given row. Transfers are stored as a linked pair (`transfer_related_id`), so deleting one leg leaves a phantom income/expense on the other account, silently corrupting balances.
**Fix:** look up `transfer_related_id` and delete both rows in one transaction.

### 1.2 Transfer edit is destructive and non-atomic
`backend/main.py:233-263` — converting/editing a transfer DELETEs the original rows, commits, closes the connection, then calls `create_transfer_transactions` on a new connection. If creation raises (e.g. bad amount string → `float()` ValueError), the original transaction is already gone. Also `int(transaction_to_update.get("amount", 0))` crashes with `TypeError` if the stored amount is NULL.
**Fix:** do delete + insert inside a single connection/transaction; validate amount before deleting.

### 1.3 Editing one leg of an existing transfer desyncs the pair
`backend/main.py:265-294` — if a user edits a transfer leg but the type stays/changes to non-transfer, only one row is updated (amount/date), leaving the pair inconsistent. Additionally, the transfer re-creation path always resets description to `"Transfer"` and assumes the edited leg is the *outgoing* one (`account_id` = from), which is wrong when editing the incoming leg.

### 1.4 EditModal can't properly edit an existing transfer
`frontend/src/components/EditModal.vue:112-137` — when opening a transfer leg, `to_account_id` is always null (the DB row only has `transfer_related_id`), so the user is forced to re-select the To account or gets the validation alert. Backend should return (or frontend derive) the counterpart account.

### 1.5 Incoming transfers counted as income in account view
`frontend/src/views/AccountTransactions.vue:211-224` — `incomeCategorySummary` only checks `tx.type !== 'income'`; unlike `AllTransactions.vue:282` it does **not** exclude `category === 'Transfer'`. The incoming leg of a transfer (type `income`, category `Transfer`) shows up as an income category, and because `monthlyStats.income` *does* exclude transfers, percentages can exceed 100%.
**Fix:** add the same `tx.category === 'Transfer'` exclusion.

### 1.6 UTC date used for "today" in the manual-entry form
`frontend/src/components/Home.vue:215` and `:394` — `new Date().toISOString().substr(0, 10)` returns the **UTC** date. In Malaysia (UTC+8) any entry before 8:00 AM defaults to yesterday's date, while the time field uses local time.
**Fix:** build the date from local components (`getFullYear/getMonth/getDate`).

### 1.7 SearchModal deletes with no confirmation
`frontend/src/components/SearchModal.vue:80` — the delete button calls the composable's `deleteTransaction(id)` directly. Every other view shows `ConfirmDeleteModal` first. One mis-tap in search = permanent deletion (and if it's a transfer leg, see 1.1).

### 1.8 Subscription auto-record race → duplicate transactions
`frontend/src/App.vue:124` posts `/api/subscriptions/check` on every app mount; `backend/main.py:376-423` does a read-check-write on `subscriptions.json` with no locking. Two devices (or two tabs) opening near-simultaneously both pass the `last_recorded_date` check and each create the transaction. Waitress runs 4 threads (`run_waitress.py:27`), so this is a real race.
**Fix:** add a lock (threading.Lock or move subscriptions into SQLite with a unique constraint on `(sub_id, month)`).

### 1.9 JSON file read-modify-write races (accounts, subscriptions, budgets)
`backend/main.py` — `save_account`, `save_subscription`, `save_budget_for_month` all do load → mutate → dump with no locking and non-atomic writes (a crash mid-`json.dump` truncates the file; the loaders then silently return `[]`/`{}` — i.e. all accounts "disappear"). 
**Fix:** write to a temp file + `os.replace`, guard with a lock — or migrate these three into SQLite tables (preferred; the DB is already there).

### 1.10 Transaction IDs from `datetime.now().isoformat()`
`backend/main.py:147` — two inserts in the same microsecond collide on PRIMARY KEY (bulk operations, subscription check creating several transactions in a tight loop is exactly this pattern). Use `uuid4()`.

### 1.11 Null/malformed amounts crash the frontend
`get_all_transactions` (`backend/main.py:93-98`) passes through non-integer amounts unformatted and NULL amounts as `None`. Every summary computed (`AllTransactions.vue:186`, `AccountTransactions.vue:176`, etc.) calls `tx.amount.replace('RM', ...)` — a single NULL-amount row throws and blanks the whole summary page.
**Fix:** never return null amounts (coalesce to "RM 0.00"), and/or guard in frontend.

### 1.12 Upload filename handling
`backend/app.py:38-41` — `secure_filename()` can return `''` (e.g. non-ASCII-only names → save to directory path fails); concurrent uploads with the same filename overwrite each other before one gets deleted in `finally`. `UPLOAD_FOLDER = 'img'` is CWD-relative (works only because `start.sh` cd's into backend).
**Fix:** save to a `tempfile.NamedTemporaryFile` (or uuid name) under an absolute path.

### 1.13 Subscription with missing/invalid amount → permanent 500 on app load
`check_and_record_subscriptions` → `create_manual_transaction` → `float(None)` raises `TypeError`. Since the check runs on every app mount, one bad subscription record breaks startup flow for every client. Validate on save (`POST /api/subscriptions` only checks key presence, not that amount parses).

### 1.14 Subscriptions skip months when the app isn't opened
`backend/main.py:387` — the check only looks at the current month; if no client hits `/check` during a month, that month's charge is never recorded (may be acceptable, but it's undocumented behavior).

---

## 2. Unused / Dead Code (safe deletions)

| Item | Location | Notes |
|---|---|---|
| `InfoExtractionMLX.py` | `backend/` | Standalone experiment; duplicates `receipt_extractor.py`, never imported |
| Budget feature (backend only) | `backend/app.py:118-143`, `backend/main.py:315-333`, `budgets.json` | **Zero frontend references** to `/api/budget`. Either delete or build the UI (see §6) |
| `json_date_converter` | `backend/main.py:60-63` | Never called |
| Root `main.py` | project root | "Hello from scandy!" placeholder |
| Root `package.json` + `node_modules/` | project root | Only contains chart.js/vue-chartjs — never imported anywhere. Delete both |
| `chart.js`, `vue-chartjs` | `frontend/package.json` | Not imported in any source file |
| `ThemeSwitcher.vue` | `frontend/src/components/` | Never mounted anywhere |
| `themeStore.js` | `frontend/src/` | Imported in App.vue "to initialize", but App.vue then force-adds `dark` class (`App.vue:119`); the light/dark toggle system is dead. Also conflicts: themeStore sets `documentElement.className = 'light'` on load, then App adds `dark` — pick one |
| `useTransactions.deleteTransaction/updateTransaction` | `composables/useTransactions.js:35-59` | Only SearchModal uses them; other views duplicate raw axios calls (see §4) — consolidate, don't keep both paths |
| `totalBalance` in Home.vue | `Home.vue:227,235` | Computed and returned, never rendered |
| Commented-out favicon route | `backend/app.py:18-20` | Delete |
| `frontend/.env.production` (`VUE_APP_API_BASE_URL`) | | Variable never read; the real base URL is hardcoded (see 3.1). Wire it up or delete |
| `ollama` dependency | `pyproject.toml`, `backend/requirements.txt` | Not imported anywhere |
| `torch`, `torchvision` | `pyproject.toml` | mlx-vlm doesn't need torch; ~2 GB of dead deps — verify then remove |
| `git_backups/` | project root | Gitignored consolidation backup from the repo merge — delete from disk |
| `waitress.log`, `.DS_Store` files | `backend/`, misc | Local clutter (already gitignored) |

---

## 3. Stability & Deployment

### 3.1 Hardcoded Tailscale IP in the app bundle
`frontend/src/App.vue:78` — `axios.defaults.baseURL = 'http://100.69.155.6:5001'`. Change of Tailscale IP = rebuild the Android app. Use `process.env.VUE_APP_API_BASE_URL` (the `.env.production` scaffolding already exists) or better, MagicDNS hostname.

### 3.2 Tailwind CDN + Google Fonts CDN at runtime
`frontend/public/index.html` — `cdn.tailwindcss.com` is explicitly not for production: full JIT compiler ships to every client, restyles on the fly (slow first paint, layout flash), and **requires network** — in the Capacitor app, offline/flaky network means no styling and no Material Symbols icons at all (icon names render as raw text).
**Fix:** install Tailwind as a PostCSS build dep (config already exists inline — move it to `tailwind.config.js`), self-host the two fonts (`@fontsource/space-grotesk`, `@fontsource/inter`, material-symbols npm package).

### 3.3 Error responses leak internals
`backend/app.py` catch-alls return `str(e)` to the client (e.g. `:58`, `:79`, `:102`). Log the traceback server-side, return a generic message.

### 3.4 `/api/logs` is an unauthenticated print sink
`backend/app.py:216-223` + CORS fully open + bind `0.0.0.0`. Fine on a Tailscale-only network, but nginx also fronts this — anyone who can reach it can spam the log or inject control chars into the terminal. At minimum: length-limit and sanitize, or gate to debug builds.

### 3.5 OCR requests serialize and block
`receipt_extractor.py` — `_GPU_LOCK` around `generate()` is correct for MLX, but a slow scan blocks one of 4 waitress threads for many seconds; a second concurrent scan blocks a second thread waiting for the lock. Model also loads inside a request (first scan is very slow) and never unloads.
**Fix (any of):** eagerly load at startup in a background thread; add a request timeout / 429 when the lock is held; consider a small job queue if multi-user.

### 3.6 OCR result requires *both* amount and date
`backend/main.py:68` — if the model reads the amount but not the date, the whole scan is discarded. Accept partial results and let the ConfirmationModal (which exists precisely for this) fill the gaps — default date to today server- or client-side.

### 3.7 Dependency manifests disagree
`pyproject.toml` (uv, py3.13, pins mlx-vlm) vs `backend/requirements.txt` (no mlx-vlm, no pins). Pick uv/pyproject as the single source; make requirements.txt generated (`uv export`) or delete it. `README`/scripts still call the project "ReceiptOCR" — cosmetic.

### 3.8 No tests
Zero test files. Priority coverage: money math (float→cents→"RM x.xx" round-trips in `main.py`), transfer pair create/edit/delete integrity, subscription recording idempotency.

---

## 4. Structure & Duplication

### 4.1 `AllTransactions.vue` ≈ `AccountTransactions.vue` (~80% identical)
Both duplicate: `monthNames` array (declared 6× across the two files), `availableYears`/`availableMonths`/`filteredTransactions`, `monthlyStats`, both category summaries, the full edit/delete/detail-modal plumbing, and near-identical templates. This is where bug 1.5 came from — logic drifted between the copies.
**Fix:** extract a `useMonthlyFilter(transactions)` composable + a `<CategorySummaryList>` component; `AccountTransactions` becomes `AllTransactions` + an account filter.

### 4.2 `EditModal.vue` ≈ `ConfirmationModal.vue`
Same form (type buttons, date overlay trick, time, amount, account/category/to-account selects), same validation, same date conversions. Merge into one `TransactionFormModal` with a mode prop.

### 4.3 Amount/date parsing scattered everywhere
`parseFloat(tx.amount.replace('RM', '').trim())` appears 8+ times; `DD/MM/YYYY ↔ YYYY-MM-DD` conversion logic appears in 5 files. Root cause: **the API returns display strings instead of data**. 
**Fix (best):** API returns `{ amount_cents: 1250 }` (or a plain number) + ISO dates; frontend formats via one `formatRM()` util and derives display dates. Kills a whole class of NaN bugs (1.11) and simplifies every computed.

### 4.4 Inconsistent data-fetch patterns
Accounts are fetched with bespoke axios calls in 5 different components; `useTransactions` exists but its update/delete helpers are bypassed everywhere except SearchModal. Add `useAccounts()` composable (singleton, like transactions) and route all mutations through the composables; use the optimistic-update pattern already written there instead of full refetch after every save.

### 4.5 Modal duplication
`BaseModal.vue` exists but only `CategoryDetailModal` uses it; AccountsPage and SubscriptionsPage inline their own modal markup, and delete-confirmation is `ConfirmDeleteModal` in some views but browser `confirm()` in AccountsPage/SubscriptionsPage. Standardize on BaseModal + ConfirmDeleteModal.

### 4.6 Route by account *name*
`router/index.js:28` — `/accounts/:name` breaks on rename and needs the extra name→id resolution in `AccountTransactions.vue:304-310`. Route by id, pass name for display.

### 4.7 `registerPlugin('SendIntent')` duplicated
Declared in both `App.vue:61` and `Home.vue:190`. Move into `useIntent.js`.

### 4.8 Sorting/normalization belongs in the DB
`sort_transactions` (`backend/main.py:105-142`) parses two date formats and two time formats per row per request, in Python, over the whole table. Store one canonical format (ISO `YYYY-MM-DD`, `HH:MM:SS` — one-time migration for existing rows), then `ORDER BY date DESC, time DESC` with an index. Also lets the transactions endpoint accept `?year=&month=` later instead of shipping the entire table to the client on every page load (currently every view refetches everything on mount).

---

## 5. Efficiency / Responsiveness (smaller wins)

- `get_account_balances` (`backend/main.py:463`) calls `get_all_transactions()`, which formats every amount to "RM x.xx" string, then immediately re-parses those strings back to cents. Use one `SELECT account_id, type, SUM(CAST(amount AS INTEGER)) ... GROUP BY` instead.
- `App.vue` fetches transactions on mount *and* every routed view fetches them again on its own mount — 2 identical requests per navigation to Home. Cache-first: fetch only if empty, add explicit refresh after mutations (composable already centralizes this).
- Home.vue duplicated form-reset object (`:214-223` and `:393-402`) — extract `makeEmptyForm()`.
- `logger.js` POSTs every log line to the server, including on web where console suffices; a dead backend makes each log also print a failure. Buffer/batch or restrict to native platform.
- SearchModal recomputes filter on every keystroke over all transactions — fine at current scale; debounce if the table grows.
- `AllTransactions.vue` fetches subscriptions just for "Safe to Spend"; `remainingSubscriptions` trusts `parseFloat(sub.amount)` (NaN poisons the sum — same validation gap as 1.13).

---

## 6. Feature Suggestions (add / remove)

**Add:**
1. **Budget UI** — backend endpoints are done (§2); a monthly budget bar on the Summary page would make "Safe to Spend" meaningful. (Or delete the endpoints.)
2. **CSV export** of transactions — trivial endpoint, high value for a money app.
3. **Category editing** — categories are hardcoded in `backend/main.py:38-58`; move to a table/JSON with CRUD, since the API is already shaped for it (`/api/categories`).
4. **Date-range picker / month navigation on Home** — Recent Logs shows only 5 with no way to see more except Search.
5. **Backup/restore** — the SQLite file + 3 JSON files are the user's whole financial history; add a simple export-all endpoint (zip) given there's no other backup path.

**Remove / de-scope:**
- Theme toggle system (dead — app is dark-only by design now): delete ThemeSwitcher, themeStore, and the light-theme leftovers.
- Budget endpoints if not building the UI.
- `GIF` from `ALLOWED_EXTENSIONS` (receipts aren't gifs; mlx-vlm may choke on animation).

---

## Suggested fix order

1. **Data integrity:** 1.1, 1.2, 1.3 (transfer lifecycle), 1.9/1.8 (JSON races → move accounts/subscriptions into SQLite), 1.10 (uuid ids).
2. **Crash-proofing:** 1.11, 1.13, 1.12, 3.3.
3. **API returns numbers not "RM" strings** (4.3) — do this before frontend refactors; it simplifies them.
4. **Frontend dedup:** 4.1, 4.2, 4.4 (fixes 1.5 structurally), plus quick bugs 1.6, 1.7, 1.4.
5. **Dead code sweep** (§2) + dependency cleanup (3.7).
6. **Build/runtime hardening:** 3.1, 3.2, 3.5.
7. Features (§6) as desired.
