# Scandy — Flutter client

The Scandy user interface: one Flutter codebase serving the Android app and the
web UI. It talks to Supabase directly — Postgres through `supabase_flutter`,
plus one Edge Function — and holds no data of its own.

This replaced a Vue 3 + Capacitor frontend, and later a Flask API on the LAN.
Every figure the redesign introduced is still derived here, on the client.

Building and configuring it lives in the [root README](../README.md); the
schema and the policies in [supabase/README.md](../supabase/README.md); the
deploy in [DEPLOYING.md](../DEPLOYING.md). This file is about working on the
app itself.

---

## Two compositions, one codebase

`AppShell` picks a layout by window width, at the `desktopBreakpoint` (900px)
defined in `lib/ui/desktop/desktop_widgets.dart`:

| | Below 900px | 900px and up |
|---|---|---|
| Navigation | Bottom bar, ADD in the centre slot | 236px sidebar |
| Settings | Pushed from the header | A sidebar destination |
| Lists | Stacked cards | Tables with column headers |
| Adding | Sheet above the nav | Buttons and cards in the page |

Both are transcribed from the design handoff's own frames rather than one being
a stretched version of the other. The selected destination survives a resize
across the breakpoint.

## Running it

Every `run` and `build` needs the two Supabase defines — see
[Where the data lives](#where-the-data-lives).

```bash
flutter pub get

flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>

# A connected Android phone (flutter devices) — same two defines
flutter run -d <device-id> --dart-define=... --dart-define=...
```

Built with Flutter 3.47 / Dart 3.13. CI pins 3.47.2, and
[DEPLOYING.md](../DEPLOYING.md) explains why.

## Building

```bash
# Web — output in build/web
flutter build web --release --pwa-strategy=none \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>

# Android — also needs android/key.properties (see key.properties.example)
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

`--pwa-strategy=none` is deliberate. The generated service worker caches the
whole app per origin and keeps serving it after a rebuild, so a redeploy looks
like it did nothing until the browser decides to update. `main.dart.js` keeps
its name across builds for the same reason, which is why the Vercel deploy
sends `Cache-Control: no-cache` over the whole output — see
[DEPLOYING.md](../DEPLOYING.md).

## Where the data lives

There is no address to configure at runtime and no **Settings → Server** any
more. `SUPABASE_URL` and `SUPABASE_ANON_KEY` are compile-time constants read by
`lib/services/supabase_config.dart`, and a build without them opens on
"Scandy is not configured" instead of the app — there is nothing to type in to
fix it. The [root README](../README.md#where-the-data-lives) says where the two
values come from.

`lib/services/scandy_repository.dart` is the data layer — every query and the
three RPCs (`create_transfer`, `rename_category`, `record_due_subscriptions`).
Nothing in it passes a user id: the policies derive that from the caller's
token, so a query cannot be pointed at somebody else's rows even by mistake.

Auth is the exception to that funnelling. `ui/auth/` and the account card in
Settings call `Supabase.instance.client.auth` directly — sign in, sign up,
password reset, display name, sign out — with `services/auth_errors.dart` as
the one place Supabase's developer-facing messages become a sentence worth
showing someone, in the reader's language.

## Layout of `lib/`

```
main.dart              Supabase.initialize, providers, theme, the /settings route
l10n/*.arb             Every string, English and Simplified Chinese
models/                Row types and the derived figures
services/supabase_config.dart   The two --dart-defines
services/scandy_repository.dart Every query, RPC and auth call
services/auth_errors.dart       Supabase's error strings, turned into sentences
services/local_scanner*.dart    ML Kit on the phone; a stub on the web
services/receipt_rules.dart     Fields out of recognised text
services/receipt_scanner.dart   The scan-receipt Edge Function fallback
services/share_intent_service.dart
state/app_state.dart          Transactions, accounts, subscriptions, categories
state/theme_controller.dart   Light/dark/system, persisted
state/locale_controller.dart  English/Chinese/follow the phone, persisted
theme/tokens.dart      Colours and radii as a ThemeExtension
theme/app_theme.dart   The type scale — ScandyText (phone), ScandyDesktopText
ui/auth/               AuthGate and the sign-in, sign-up and reset screens
ui/shell/              AppShell, bottom nav, the add sheet
ui/desktop/            Sidebar and the desktop composition of every screen
ui/home|summary|accounts|recurring|settings/   The phone compositions
ui/common/             Cards, sheets and the shared widget vocabulary
ui/transactions/       Add/edit form, search, detail sheet
util/                  Formatting and category icons
```

Phone and desktop screens share the models, state and sheets; they differ only
in composition. `ScandyText` is the phone type scale and `ScandyDesktopText` the
desktop one — separate scales, not overrides, because the goldens assert against
the former.

## Things worth knowing before you edit

**Money is integer cents.** `transactions.amount_cents` is a `bigint`, always
positive; the direction lives in `type`, and a check constraint enforces the
pair. `Transaction.fromRow` signs it on the way in, so all arithmetic goes
through `Transaction.amountCents` and formatting stays on the screen. There is
no pre-formatted amount on the wire — a display string cannot be summed without
losing money.

**Dates arrive as ISO.** `occurred_on` is a `date` and `occurred_at` a `time`,
parsed at the model boundary; only `HH:MM` is ever shown. (The doc comment on
`Transaction.date` still says DD/MM/YYYY — it predates the migration and the
code below it does not.)

**Transfers are two real rows**, one income and one expense, sharing a
`transfer_group_id`. They are excluded from every spending and income figure
(`MonthSummary`, `MonthStats`) or they would double-count money moving between
your own accounts. They are *not* excluded from an account's transaction count,
where both legs are real. Creating one is an RPC, not two inserts, so a half-made
transfer is not possible.

**Scanning has two paths, and the cloud one is capped.** On a phone, ML Kit plus
`receipt_rules.dart` answer offline in well under a second. On the web, and when
a phone read comes back missing a field, `receipt_scanner.dart` invokes the
`scan-receipt` Edge Function, which is rate limited per person per day and
reports failure as a `FunctionException` carrying a sentence written for the
user. Either path only extracts — nothing is saved until the form is submitted.

**Everything is behind `AuthGate`.** It owns the session, so a screen can assume
there is a signed-in user; row level security assumes it too, and a query that
somehow runs signed-out returns nothing rather than everything.

## Share intent

A receipt shared from another app opens straight in the scanner
(`ShareIntentService` + the `SEND` / `SEND_MULTIPLE` filters in
`android/app/src/main/AndroidManifest.xml`).

The cold-start case is the fiddly one: `start()` runs in `main()`, before
`runApp`, so the share that launched the app is delivered while there is no
widget tree to receive it — and a broadcast stream drops events that have no
listener. Those are queued and replayed when the shell subscribes, then handled
post-frame, because the replay lands during `initState` before there is a
Navigator to host the scanning dialog.

## Tests

```bash
flutter test
```

`month_summary_test.dart` pins the safe-to-spend arithmetic, including the
transfer exclusion. `home_golden_test.dart` renders Home in both themes from
model fixtures reproducing the design's own figures — there is no HTTP left to
mock, so the fixture is the data itself — and dates are injected rather than
read from the clock, or "24 days left" would break at midnight.
`test/flutter_test_config.dart` registers the bundled fonts so the goldens show
real type instead of Ahem boxes.

The goldens are tagged, and CI runs `flutter test --exclude-tags golden`
because pixels differ across platforms and Flutter versions; run the full suite
locally before pushing a UI change. [DEPLOYING.md](../DEPLOYING.md) has the
reasoning and the `--update-goldens` command.

`integration_test/` holds the on-device check, which needs a real phone —
that is the only place ML Kit actually exists. The other screens have no golden
coverage yet.

## Icons

Launcher and web icons are generated from `assets/icon/app_icon.png` — the mark
the Capacitor build shipped, kept so the home screen looks unchanged. After
editing the art:

```bash
dart run flutter_launcher_icons
```

The config is in `pubspec.yaml`. The adaptive foreground is the same full-bleed
art; the generator insets it 16% into Android's safe zone, which matters because
the orange rule runs almost the whole height and would otherwise lose both ends
to the circular mask.

## Fonts

Plus Jakarta Sans is bundled in `assets/fonts` rather than fetched at runtime.
Scandy is expected to open offline, where a runtime fetch silently falls back to
the system face and changes every metric the design specifies.

## Network

Every request goes to Supabase over HTTPS, and the Android build keeps the
platform default of blocking cleartext. There used to be a
`network_security_config.xml` allowing plain HTTP app-wide for a self-hosted
backend on the LAN; that backend is gone, and the exemption went with it.
