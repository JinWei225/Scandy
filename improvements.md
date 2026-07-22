# Scandy — Code Audit & Improvement Plan

Audit date: 2026-07-17. Reference notes for future fixes. File/line refs are from the state of the repo at commit `dda8960`.

## Status update — 2026-07-17 (post-fix pass)

**Done in this pass:**
- §1 bugs **1.1–1.13 all fixed** (1.14 deferred by choice — missed months are still not backfilled).
- §2 dead code removed: budget feature (endpoints + functions + budgets.json), `InfoExtractionMLX.py`, root `main.py`, root `package.json`/`node_modules`, `git_backups/`, chart.js/vue-chartjs, `json_date_converter`, commented favicon route, `totalBalance` dead state, `ollama` dep. **`torch`/`torchvision` had to stay** — transformers' Qwen3-VL processor needs torchvision at model-load time (verified: removal breaks OCR). Removed files are in `~/.Trash/scandy-cleanup/`.
- **Kept intentionally:** `ThemeSwitcher.vue` / `themeStore.js` — user wants light mode back later. `.env.production` still unwired (part of 3.1, not done).

**Still open:** everything in §3 (stability/deployment), §4 (structure/duplication), §5 (efficiency), §6 (features), and bug 1.14.

## Status update — 2026-07-22 (fifth pass: phone-first UI — modal flows, density, warm light theme)

Driven by usage: the app is used almost exclusively on a phone, and Home was a long scroll past two idle forms to reach the ledger.

**Home is now a ledger with two buttons.** The always-open Upload and Manual Log sections became two action cards launching modal flows — scan: `ScanModal` → `TransactionFormModal` ("Confirm Details") → `ResultModal`, with cancel stepping back to the *scan* modal; manual: form → result. One `flow` ref (`null|'scan'|'form'|'result'`) plus `flowSource` drives both paths.
- **New:** `ScanModal.vue` (camera + file picker; owns selection only and emits `scan(File)`, so the Android share intent drives the same code) and `ResultModal.vue` (reusable success/error step). Both wrap `BaseModal`. `TransactionFormModal` gained one additive `cancelLabel` prop.
- `handleSaveConfirmation` + `addManualTransaction` collapsed into one `commitTransaction`; on failure the result modal offers "Back To Form" with entered values preserved.
- **Share intent:** opens `ScanModal` in a loading state and auto-uploads. `consumeIntent()` moved to `closeFlow()` so it fires however the flow ends; the `intentConsumed` remount guard still holds.

**§6.4 revised — Home date range defaults to the last 3 days** (today − 2 → today). Both bounds show real dates under From/To captions, and ✕ became a ⟳ reset. The old "no range = 5 newest" fallback is dead and removed; the count moved beside the "Recent Logs" heading, where it no longer wraps the filter onto a third line.

**Density pass (the app was showing ~1 log per screen).**
- `html { font-size: 15px }` in `main.css` shrinks every rem-based utility ~6% from one line. Arbitrary pixel utilities (`text-[10px]`, icon sizes) deliberately don't scale — already at floor size.
- **`TransactionRow.vue` extracted** from three near-identical copies (Home, `SearchModal`, `CategoryDetailModal`), ~90 lines of duplication removed — same fix as §4.1/4.2. **One DOM serves both layouts:** mobile is a `grid-cols-[1fr_auto]` 2×2 (two lines, not five); at `md` the meta wrapper flips to `display: contents` so date and category drop into the parent 12-column grid, with `md:order-*` restoring table order. The description `truncate`s — that's what holds the row to two lines.
- Same two-line shape on **Accounts** and **Recurring**; their text buttons became Home's bare icon buttons (with `aria-label`s).
- **Type contrast:** metadata down, primary values up — descriptions/amounts and account/subscription names up one step, type and category chips to `text-[9px]`, the Summary per-category count to `text-[9px]`/80% so it reads as a footnote.
- Headers tightened uniformly (`mb-12 → mb-6`, titles and hero totals down one step, rows `py-2.5 px-3`). **Settings is the deliberate exception** at `text-4xl md:text-5xl`, so it out-weighs its section labels.
- **Summary/Account year+month filters are side by side at every width**; stacking two short values cost a full row. **Settings category lists collapse by default** — together they ran past a phone screen and are rarely edited. Collapsing clears any in-progress rename, which would otherwise reappear on the next expand.

**Native header wasted a band of screen.** `body.is-native header` had `padding-top: calc(1.5rem + env(safe-area-inset-top))` — the 1.5rem sat *on top of* the inset, pushing the title ~24px down. Now `0.25rem`, plus `main` `pt-8 → pt-4` under `md`: ~40px reclaimed on every page.

**Light theme rehued.** M3's light neutrals derive from the orange seed but lean red, reading pink at those tones. The `html.light` ramp is now warm orange (`--c-background`/`--c-surface`/`--c-surface-bright` `#fff8f6 → #fff6eb`, container/variant/dim steps and `--c-outline-variant` to match). Text tokens unchanged (still AA); dark theme untouched.

**Modal backdrops are now a scrim** (`bg-surface/90 → bg-on-surface/40`, all three copies). In light mode `--c-surface` equals `--c-background`, so panel, backdrop, and page behind were one flat colour separated only by a hairline.

**Tapping a row opens a read-only detail view.** New `TransactionDetailModal.vue` (wraps `BaseModal`) lists the same fields as the edit form — type, amount, description, date/time, account, category, or from/to for transfers — with no inputs. `TransactionRow` emits `select` on row click; the edit/delete buttons `@click.stop` so they stay actions on the row rather than a way into the detail view. View state lives in `useTransactionModals`, so Home, Search, Summary, and Account views all get it from the same place. With the detail view available, **Home's rows dropped the category chip** (`:showCategory="false"`) — it was the least-scanned item on an already dense row. The row's description widens to `md:col-span-6` when the chip is hidden so the desktop grid still totals 12.

**Verified:** `npm run build` clean (only the pre-existing font/bundle warnings), `npx cap sync` run. Functional testing was manual on-device — flows, share intent + remount guard, and a modal regression sweep passed. The camera path was checked only for "opens the camera and populates the filename"; no physical receipt was scanned through it.

## Status update — 2026-07-18 (fourth pass: 1.14 decision, 3.7, 4.5, project rename)

**Done in this pass:**
- **1.14 — resolved as won't-fix (see §1.14 below).** No backfill implemented, by choice. Two visibility mitigations shipped instead: `App.vue` now surfaces auto-recorded charges in a dismissible banner (the `{created: [...]}` response was previously discarded) and refreshes the ledger; `SubscriptionsPage` shows a per-row "Last charged <date>" / "Never charged" line so a skipped month is visible.
- **3.7** — `backend/requirements.txt` is now a generated pinned export of `uv.lock` (`uv export --no-dev --no-hashes --no-emit-project -o backend/requirements.txt`), carrying uv's autogenerated header. The old hand-written list was missing `mlx-vlm`/`torch`/`torchvision`, so installing from it produced an env where OCR could not import. Both READMEs now document `uv sync` as the primary path with pip as a documented fallback.
- **4.5** — `BaseModal` gained a `size` prop (`sm`/`md`/`lg`, default `lg` so `CategoryDetailModal` is unchanged), responsive padding/title (`p-5 sm:p-8`, `text-xl sm:text-2xl`), and an Esc-to-close handler. `AccountsPage`, `SubscriptionsPage`, and `TransactionFormModal` now use it — backdrop copies went 6 → 3. **`ConfirmDeleteModal` and `SearchModal` are deliberately not migrated:** the former needs `z-[200]` to stack *above* BaseModal and has an icon+title+message header BaseModal can't express; the latter is top-aligned with self-padded sections. Absorbing them would mean `align`/`padded`/header-slot props for one caller each.
- **Project renamed ReceiptOCR → Scandy**, including the Android package `com.jinwei.receiptocr` → `com.jinwei.scandy` (gradle `namespace`+`applicationId`, `strings.xml`, `capacitor.config.json`, Java package dir via `git mv`). `AndroidManifest.xml` needed no edits — it already indirects through `@string/app_name`, `.MainActivity`, and `${applicationId}.fileprovider`. Verified: `./gradlew assembleDebug` succeeds and the APK reports `com.jinwei.scandy`.
  - **`deploy.sh` now `rm -f`s the old `receiptocr.conf`** before writing `scandy.conf`. This is load-bearing: `nginx.conf` is a catch-all (`server_name _`), so leaving the old file would create two competing server blocks on port 80.
  - **Consequence:** because `applicationId` changed, Android treats this as a *new app*. The next build installs **alongside** the existing ReceiptOCR app rather than upgrading it — uninstall the old one manually. Only the `localStorage` theme preference is lost; all financial data lives in the backend SQLite DB.
- **Bottom nav broke on phones using 3-button navigation.** The nav had a fixed `h-20` *plus* `padding-bottom: env(safe-area-inset-bottom)`. Tailwind's preflight sets `box-sizing: border-box`, so the total stayed 5rem and the padding ate the content box instead: with a ~48px system-nav inset only ~32px was left for an icon+label stack needing ~42px, so the icons overflowed **above** the bar's painted background (gesture mode has a ~0-24px inset, which is why it only showed up in button mode). Replaced `h-20 pb-safe` with a single `.bottom-nav-safe` class setting `height: calc(5rem + env(safe-area-inset-bottom))` *and* the padding together, so the bar grows with the inset rather than absorbing it — and the two values can't drift apart again. `main`'s `pb-24` likewise became `.pb-nav-safe` (`calc(6rem + inset)`, scoped under the `md` breakpoint) so the last row of content still clears the taller bar.
- **Modals ignored safe-area insets too** (same root cause, found while fixing the nav). Backdrops are `fixed inset-0`, so they span the strip under the system nav bar and the status bar/notch, and the panels' `max-h-[90vh]`/`max-h-[80vh]` used `vh` — which also ignores insets. On a tall modal in 3-button mode the action row could sit behind the system bar. Added a shared `.modal-inset-safe` utility in `src/assets/main.css` (padding on all four edges = `1rem + env(safe-area-inset-*)`, so landscape notches are covered as well) and switched the panels to `max-h-full`, making the height container-relative so the inset is accounted for in exactly one place. `SearchModal` is top-aligned and keeps its larger offset via `.modal-inset-safe-top` (`4rem + inset`). `TransactionFormModal` inherits the fix through `BaseModal`. `ConfirmDeleteModal` got only the padding — its panel is a short fixed template that never approaches viewport height, and adding a scroll container would have broken its absolutely-positioned accent bar.
- **Stale docs corrected while in the files:** README no longer lists **Ollama** as a prerequisite (removed as dead code in §2), and `backend/README.md` no longer documents the deleted `/api/budget` endpoints (it now lists the category CRUD and `/api/subscriptions/check` routes that actually exist).

**Build environment note:** `./gradlew assembleDebug` fails under the default JDK (Homebrew OpenJDK **26**) with `Unsupported class file major version 70` — Gradle 9.1.0 supports up to Java 25. This predates this pass and is unrelated to the rename. Workaround: `export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"` (JDK 21).

## Status update — 2026-07-18 (third pass: 4.8, category editing, Home date range)

**Done in this pass:**
- **4.8** — Dates now stored canonical ISO (`YYYY-MM-DD`) with `HH:MM:SS` times. Idempotent startup migration (`migrate_datetime_format` in `backend/main.py`) rewrote all 926 rows and created `idx_tx_date_time`; `GET /api/transactions` uses `ORDER BY date DESC, time DESC` (Python `sort_transactions` deleted). The API surface is unchanged: still serves/accepts DD/MM/YYYY, converted at the storage boundary (`_to_iso_date`/`_to_display_date`/`_normalize_time`) — zero frontend changes needed. Verified: post-migration API order byte-identical to the old Python sort.
- **§6.3 (category editing)** — Categories moved from a hardcoded dict to `backend/categories.json` (seeded with the old defaults, guarded by `_JSON_LOCK` + atomic writes). New `POST/PUT/DELETE /api/categories`; rename cascades to existing transactions and subscriptions.json, delete keeps old logs' labels; "Transfer" reserved, last category of a type undeletable. Managed from the new **Settings page** (`/settings`, 5th nav tab) which also hosts the ThemeSwitcher (moved out of the header; `themeStore` now imported eagerly in `main.js` so the saved theme still applies at startup). Home/dropdowns use the `useTransactions` categories singleton, so edits propagate live.
- **§6.4 (Home date range)** — From/To date-range picker above Recent Logs; no range = previous 5-newest behavior, any bound set = all matching logs (open-ended ranges supported) with a count badge and clear button.
- **Subscriptions edge fix** — due day is clamped to the month's length, so a day-31 subscription now charges correctly in shorter months.
- `frontend/vue.config.js` dev proxy target overridable via `DEV_API_TARGET` env (default unchanged: 5001).

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

**Still open (as of 2026-07-22, after the fifth pass):** 3.8 (no automated tests — still the biggest gap; the fifth pass was verified entirely by hand on-device), §6 remaining features (CSV export, backup/restore). Optional: subset the 3.9 MB Material Symbols variable font to only the ~22 icons used; migrate `SearchModal`/`ConfirmDeleteModal` onto `BaseModal` if it ever grows `align`/`padded`/header-slot props (deliberately skipped — see fourth pass; note the fifth pass had to hand-edit the backdrop line in all three copies, which is the cost of that decision showing up). 1.14 is closed as won't-fix; 3.7 and 4.5 are done.

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

### 1.14 Subscriptions skip months when the app isn't opened — **WON'T FIX (decided 2026-07-18)**
`check_and_record_subscriptions` only evaluates the current month; if no client hits `/api/subscriptions/check` during a month, that month's charge is never recorded. The guard asks *"did we already charge this calendar month?"*, never *"how many due dates have elapsed since `last_recorded_date`?"* — and because the stamp jumps forward to today, skipped months leave no residue to detect later.

**Decision: not backfilling, deliberately.** Two reasons:
1. Some historical subscription charges were already entered **by hand as ordinary expenses**, so an automatic backfill would double-count them — and there is no way to tell which months were already covered without auditing the ledger manually.
2. Most subscriptions started only recently, so the genuinely missed history is small.

**Shipped instead — make the gap visible rather than silently guessed at:**
- `App.vue` surfaces the `{created: [...]}` response in a dismissible banner and refreshes the ledger. Previously the response was discarded, so auto-recorded charges appeared with zero feedback.
- `SubscriptionsPage` shows "Last charged &lt;date&gt;" (or "Never charged") per row, so a month that got skipped is now apparent at a glance.

**If backfill is ever wanted, don't auto-create.** The safe design is a **review queue**: detect elapsed periods and surface them for the user to confirm or dismiss individually. That turns an overlap with a manually-entered charge into a dismiss instead of a duplicate. Two data-model facts block a naive implementation and would need addressing first:
- **`last_recorded_date` stores the date the check *ran*, not the period charged** — `Tunetalk Epikcall20` has `day_of_month: 6` but `last_recorded_date: 2026-07-08` (the app was opened on the 8th). It is therefore not a reliable period cursor; a period-based field (e.g. `last_recorded_period: "2026-07"`) would be needed. Note `save_subscription` does a **wholesale record replace**, so any new field must be echoed by the frontend form or the endpoint must merge.
- **There is no `start_date` and no frequency field.** Every subscription is implicitly monthly with no anchor telling a backfill how far back to go.
- Also: `create_manual_transaction` opens its own connection per call, so an N-month backfill is N independent commits with the JSON stamp written only at the end — a mid-backfill crash would re-charge on the next run.

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

### 3.7 Dependency manifests disagree — **DONE (2026-07-18)**
`pyproject.toml` (uv, py3.13, pins mlx-vlm) vs `backend/requirements.txt` (no mlx-vlm, no pins). uv/pyproject is now the single source; `backend/requirements.txt` is a generated pinned export of `uv.lock` and carries uv's autogenerated header. The project rename to Scandy is also done — see the fourth-pass status update.

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

### 4.5 Modal duplication — **DONE (2026-07-18)**
`BaseModal.vue` existed but only `CategoryDetailModal` used it; AccountsPage and SubscriptionsPage inlined their own modal markup. Now standardized — see the fourth-pass status update for what was migrated and why `ConfirmDeleteModal`/`SearchModal` were deliberately left out.

*(The original entry also claimed AccountsPage/SubscriptionsPage used browser `confirm()`. That was already stale when this pass started — both had been moved to `ConfirmDeleteModal` in the second pass, and there is no `confirm()` anywhere in `frontend/src`.)*

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
