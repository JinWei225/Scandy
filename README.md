# 🧾 Scandy

Scandy is a receipt scanner and personal transaction manager. Photograph a
receipt — or share one into the app — and it reads the date, time and total
**on the phone itself**, with ML Kit, usually in well under a second and with no
network at all. You confirm the fields, and it files the transaction.

The interface is a Flutter app: one codebase for Android and the web, light and
dark themes, English and Simplified Chinese. On a phone it uses a bottom
navigation bar; on a desktop-width window it switches to a sidebar with wider,
table-based layouts.

The ledger lives in **Supabase**. There is no application server: the app talks
to Postgres directly, and row level security is what separates one person's
money from another's — so several people can share one deployment without ever
seeing each other's transactions.

| If you want | Read |
| --- | --- |
| To build and run the app | [Setup](#-setup) below |
| The schema, the policies, the Edge Function, adding a user | [supabase/README.md](supabase/README.md) |
| How the web app is built and shipped | [DEPLOYING.md](DEPLOYING.md) |

---

## ✨ Features

- **On-device receipt scanning:** ML Kit reads the image and the rules in
  `receipt_rules.dart` pick out the transaction date, time and total — offline,
  and free. Anything they cannot read, and the web build, which has no ML Kit,
  falls back to the `scan-receipt` Edge Function, which asks Gemini. Either way
  the values are shown for confirmation before saving, so a partial reading is
  never a failed scan.
- **Manual Transaction Logging:** Quickly log expenses with custom details, accounts, and types (expense vs. income).
- **Account Transfers:** Move money between accounts as a paired transaction.
- **Category-Wise Summaries:** Monthly breakdowns per category, with a drill-down into the transactions behind each one.
- **Custom Categories:** Add, rename, and delete expense/income categories from Settings. Renames cascade to existing transactions and subscriptions.
- **Subscription Tracker:** Track recurring subscriptions with monthly cost
  summaries. Charges due in the current month are recorded on app start by
  `record_due_subscriptions()` in the database rather than by the client, so two
  devices opening at once cannot record the same charge twice.
- **Multi-Account Balance Management:** Monitor balances across multiple accounts (e.g., Cash, Credit Cards, Bank Accounts), with a per-account transaction history.
- **Search:** Every term must match somewhere in the transaction — description, category, account or amount.
- **More than one person:** Everyone signs in, and row level security keeps the
  ledgers apart. Sign-up is closed to an allowlist — see *Adding someone* in
  [supabase/README.md](supabase/README.md).
- **Light & dark themes, English & 简体中文:** both chosen in Settings, both persisted.
- **Share-to-Scandy:** a receipt image shared from any Android app opens straight in the transaction form.

---

## 🛠️ Technology Stack

### The app

- **Flutter (Dart):** One codebase for Android and the web (`frontend_flutter/`)
- **Material 3 + design tokens:** A `ThemeExtension` carrying the palette, radii and type scale, with light/dark theming
- **Provider:** App state — transactions, accounts, subscriptions, categories
- **`supabase_flutter`:** Auth, Postgres and Edge Function calls
- **`google_mlkit_text_recognition`:** On-device OCR on the phone build; the web build has none, selected by conditional import
- **Flutter `gen-l10n`:** Every string in `lib/l10n/*.arb`, English and Simplified Chinese
- **Plus Jakarta Sans:** Bundled, not fetched, so the app renders identically offline

### The backend

There is no server to run — it is a Supabase project:

- **Postgres:** the source of truth, and the security boundary
- **Row level security:** every table, `using` *and* `with check`, tested in `supabase/tests/`
- **Supabase Auth:** email and password, with sign-up restricted to an allowlist table
- **One Edge Function:** `scan-receipt` (Deno), which holds the Gemini API key and caps each person at 30 cloud scans a day

[supabase/README.md](supabase/README.md) documents all of it, including the
parts that will bite you if you change them.

### Hosting

The web build is static files: GitHub Actions builds them and Vercel serves
them. See [DEPLOYING.md](DEPLOYING.md).

---

## 🚀 Setup

### Prerequisites

- **[Flutter](https://docs.flutter.dev/get-started/install)** — 3.47.2 is what CI builds with, pinned deliberately (see [DEPLOYING.md](DEPLOYING.md))
- **A [Supabase](https://supabase.com/) project** — the free tier is enough
- **[Supabase CLI](https://supabase.com/docs/guides/local-development)** — to apply the migrations
- **Android Studio** — only if you are building the Android app

```bash
git clone https://github.com/JinWei225/Scandy.git
cd Scandy
```

---

### 1. The database

[supabase/README.md](supabase/README.md) takes this end to end: pointing the
CLI at your project and pushing the migrations, deploying the `scan-receipt`
function with its Gemini key, running the row level security tests, and letting
a person sign up.

Do it before building the app — the app has nothing to talk to until the
migrations are applied.

---

### 2. The app

```bash
cd frontend_flutter
flutter pub get
```

#### Running it during development

Every `flutter run` and `flutter build` needs the Supabase project passed in —
see [Where the data lives](#where-the-data-lives) below.

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>

# A connected Android phone (flutter devices) — same two defines
flutter run -d <device-id> --dart-define=... --dart-define=...
```

#### Building for production

```bash
# Web — output lands in frontend_flutter/build/web
flutter build web --release --pwa-strategy=none \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>

# Android
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

`--pwa-strategy=none` is deliberate: the generated service worker caches the
whole app per origin and keeps serving it after a rebuild, so a redeploy looks
like it did nothing until the browser decides to update.

A release APK also needs signing secrets, which are gitignored — copy
`android/key.properties.example` to `android/key.properties` and follow the
notes in it.

Building the web app by hand is rarely necessary: a push to `main` builds it in
GitHub Actions and deploys it to Vercel, with both defines supplied from
repository secrets. [DEPLOYING.md](DEPLOYING.md) covers that workflow, and the
by-hand deploy if you need it.

#### Where the data lives

There is no application server to point the app at. The Flutter app talks to
Supabase directly, and row level security is the only thing standing between
one person's ledger and another's.

Which project it talks to is fixed at build time, in two `--dart-define`s read by
[`lib/services/supabase_config.dart`](frontend_flutter/lib/services/supabase_config.dart):

| Define | Where to find it |
| --- | --- |
| `SUPABASE_URL` | Supabase dashboard → Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | the same page — the anon (or `sb_publishable_…`) key |

Miss either one and nothing fails while building. The app compiles, installs,
and then shows **"Scandy is not configured"** to everyone who opens it, with no
in-app setting to repair it — the only fix is another build. So keep the defines
in your IDE run configuration, not just in your shell history.

The anon key is public by design: it identifies the project and nothing else,
every request it makes is still subject to row level security, and it ships
inside the bundle either way. The key that must never be built into the app —
or written down in this repository — is `service_role`, which bypasses row
level security entirely.

#### Tests

```bash
flutter test
```

Includes golden tests for Home in both themes, rendered with the bundled fonts.
CI runs `flutter test --exclude-tags golden`, and
[DEPLOYING.md](DEPLOYING.md) explains why the goldens stay a local check.

The database has its own tests — `./supabase/tests/run.sh`, which is what proves
one user cannot reach another's rows.

---

## 🗺️ Screens

| Screen | What it is |
| --- | --- |
| Home | Log a transaction, current month overview |
| Summary | All transactions and category breakdowns |
| Accounts | Balances, and a drill-down per account |
| Recurring | Subscription tracker |
| Settings | Theme, language, categories, and the account |

The app navigates in-process rather than by URL; `/settings` is the one named
route, so that the header's settings button works from anywhere.

---

## 📦 The pre-Supabase stack

`backend/`, `docker/`, `deployment/` and `compose.yaml` are the Flask + SQLite +
nginx stack Scandy ran on before the migration, when it lived on a Mac mini and
read receipts with Apple Vision or Ollama. They are kept for reference and are
**not** a way to run Scandy today: the Flutter app has no code path to that API
any more, and neither build passes the Supabase defines, so the web UI they
produce comes up as "Scandy is not configured".

The history is worth keeping in one line: everything the Mac mini used to do now
happens somewhere that does not need it awake.
