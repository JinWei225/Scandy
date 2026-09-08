# Scandy — Flutter client

The Scandy user interface: one Flutter codebase serving the Android app and the
web UI. It talks to the Flask backend in `../backend` over HTTP and holds no
data of its own.

This replaced a Vue 3 + Capacitor frontend. The API did not change with it —
every figure the redesign introduced is derived here, on the client.

Setup, self-hosting and deployment live in the [root README](../README.md).
This file is about working on the app itself.

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

```bash
flutter pub get

flutter run -d chrome          # web, hot reload
flutter run -d <device-id>     # a connected Android phone (flutter devices)
```

Built with Flutter 3.47 / Dart 3.13.

## Building

```bash
# Web — output in build/web
flutter build web --release --pwa-strategy=none

# Android
flutter build apk --release
```

`--pwa-strategy=none` is deliberate. The generated service worker caches the
whole app per origin and keeps serving it after a rebuild, so a redeploy looks
like it did nothing until the browser decides to update. For the same reason
both nginx configs in this repo send `Cache-Control: no-store`: `main.dart.js`
keeps its name across builds, so a cached copy otherwise outlives a deploy.

## Where the API lives

A Flutter binary has no origin to infer the backend from, so the address is
explicit and editable in **Settings → Server**. `ApiClient.defaultBaseUrl` is
only the first-run guess:

| Platform | Guess |
|---|---|
| Web | The page's own host, port 5001 — serve the app from the backend's machine and it just works |
| Android emulator | `http://10.0.2.2:5001` (the host machine) |
| Everything else | `http://localhost:5001` |

A physical phone needs the machine's Tailscale or LAN address. A saved address
always wins, and it is stored per platform — on the web, per origin.

## Layout of `lib/`

```
main.dart              Providers, theme, the /settings route
models/                Wire types and the derived figures
services/api_client.dart      Every endpoint, plus the base-URL preference
services/share_intent_service.dart
state/app_state.dart          Transactions, accounts, subscriptions, categories
state/theme_controller.dart   Light/dark/system, persisted
theme/tokens.dart      Colours and radii as a ThemeExtension
theme/app_theme.dart   The type scale — ScandyText (phone), ScandyDesktopText
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

**Money is integer cents.** The backend stores cents in a TEXT column and
serialises both `amount_cents` (int) and `amount` (a pre-formatted `"RM 12.34"`
string). All arithmetic goes through `Transaction.amountCents`; summing the
display string would be lossy.

**Dates arrive as DD/MM/YYYY** and are parsed at the model boundary.

**Transfers are two real rows**, one income and one expense. They are excluded
from every spending and income figure (`MonthSummary`, `MonthStats`) or they
would double-count money moving between your own accounts. They are *not*
excluded from an account's transaction count, where both legs are real.

**The scan endpoint fails in-band.** `POST /api/upload` returns HTTP 200 with an
`error` key when it cannot read a receipt, so the success path has to check for
it. It also only extracts — nothing is saved until the form is submitted.

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
transfer exclusion. `home_golden_test.dart` renders Home in both themes against
a `MockClient` reproducing the design's own figures, so the goldens are the
check that the redesign's numbers still come out right — dates are injected
rather than read from the clock, or "24 days left" would break at midnight.
`test/flutter_test_config.dart` registers the bundled fonts so the goldens show
real type instead of Ahem boxes.

The other screens have no golden coverage yet.

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

## Known constraint

Cleartext HTTP is permitted app-wide (`android/app/src/main/res/xml/network_security_config.xml`)
because the backend is self-hosted over plain HTTP. Android matches host *names*,
not CIDR ranges, so scoping this to private addresses is not expressible. Put
the backend behind HTTPS before exposing it beyond a trusted network.
