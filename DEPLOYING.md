# Deploying the web app

The Flutter web build is a directory of static files. Vercel serves it; GitHub
Actions builds it. Nothing here needs a server.

## Why the build happens in Actions

Vercel's build image has no Flutter toolchain. It can be told to download one on
every deploy, but that is a ~1 GB fetch standing between a typo and seeing the
fix. Building in Actions and shipping the finished directory keeps deploys to
seconds and makes them reproducible off any machine, including when the Mac mini
is switched off -- which is the point of the whole migration.

## Two settings that are not obvious

**The SPA rewrite.** Every path serves `index.html`, because the app routes
client-side and a refresh on any route would otherwise 404. Vercel applies
rewrites *after* checking the filesystem, so real files still win and this
catch-all only sees paths that do not exist.

**`Cache-Control: no-cache` on everything.** Flutter emits one large
`main.dart.js` under a fixed name, so a cached copy survives a redeploy and the
browser goes on running the old app -- the same reason the nginx config used
`no-store`. `no-cache` is the better version of that decision: the browser still
revalidates on every load, but an unchanged file comes back as a 304 rather than
re-downloading 3 MB. Correctness with the round trip made cheap, instead of
correctness paid for in bandwidth.

## Why the golden tests are not in CI

`matchesGoldenFile` compares actual pixels, and the pixels depend on the whole
environment, not just the code:

  - the same font at the same size rasterises differently on macOS and Linux
  - and differently again across macOS releases, because CoreText changes
  - and differently again across Flutter versions, because Skia and the text
    layout engine change with them

That last one was measured here rather than assumed: the runner installed
Flutter 3.47.3, released a day earlier, while this project is on 3.47.2. A
patch release was enough. Flutter's own repository pins its goldens to one
controlled environment for exactly this reason, and matching a GitHub runner to
a developer's laptop is not a fight worth having for two users.

So the goldens stay a local check, where they are also the most useful -- a
golden failure is a "look at the difference and decide", and nobody opens a CI
artifact to do that. Before pushing a change to the UI:

    cd frontend_flutter && flutter test          # everything, goldens included

CI runs `flutter test --exclude-tags golden`, which is the other 141.

If a change to the design was intended, re-record and commit the new PNGs:

    cd frontend_flutter && flutter test --tags golden --update-goldens

## The Flutter version is pinned

`flutter-version: 3.47.2` in the workflow, not `channel: stable`. Unpinned, the
toolchain moves under the build -- which is how the goldens broke in the first
place. Bump it deliberately, in a commit, having run the tests locally on the
same version.

## First-time setup

1. Create a Vercel project. It does not need to be connected to the repository
   -- Actions pushes the built output to it.

2. Collect four values:

   | Where | What |
   | --- | --- |
   | Vercel > Account Settings > Tokens | `VERCEL_TOKEN` |
   | Vercel > Project Settings > General | `VERCEL_PROJECT_ID` |
   | Vercel > Team/Account Settings | `VERCEL_ORG_ID` |
   | Supabase > Settings > API | the project URL and the anon key |

3. Add them under GitHub > Settings > Secrets and variables > Actions:

       VERCEL_TOKEN
       VERCEL_ORG_ID
       VERCEL_PROJECT_ID
       SUPABASE_URL
       SUPABASE_ANON_KEY

   The anon key is public by design -- it ships inside the bundle either way.
   It lives in secrets only so the workflow file stays free of project detail,
   not because exposure would matter. The key that must never appear here is
   `service_role`, which bypasses row level security entirely.

4. Push the branch. The workflow runs on every push to `main`, and can be
   triggered by hand from the Actions tab.

## After the first deploy

Change **Site URL** in Supabase > Authentication > URL Configuration to the
Vercel domain. That single field decides where confirmation and password-reset
emails send people; while it points anywhere else, those links dead-end -- which
is exactly what happened when it was still `http://localhost:3000`.

Leave `com.jinwei.scandy://login-callback` in Redirect URLs. The Android app
needs it, and it is unrelated to the web domain.

## Deploying by hand

Rarely needed, but there is no CI dependency in the app itself:

    cd frontend_flutter
    flutter build web --release \
      --dart-define=SUPABASE_URL=... \
      --dart-define=SUPABASE_ANON_KEY=...
    cp ../vercel.json build/web/
    npx vercel deploy build/web --prod --token=...
