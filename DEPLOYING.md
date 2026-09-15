# Deploying the web app

The Flutter web build is a directory of static files. Vercel serves it; GitHub
Actions builds it. Nothing here needs a server.

## Why the build happens in Actions

Vercel's build image has no Flutter toolchain. It can be told to download one on
every deploy, but that is a ~1 GB fetch standing between a typo and seeing the
fix. Building in Actions and shipping the finished directory keeps deploys to
seconds and makes them reproducible off any machine, including when the Mac mini
is switched off -- which is the point of the whole migration.

## Why the deploy is `--prebuilt`

Uploading the built directory and letting Vercel work out what it is does not
work here: it guessed Flask. This repository has a `pyproject.toml` and a
`backend/app.py`, so the project was created with a Python preset, and every
deploy then ran a Python pipeline regardless of what was uploaded --

    Error: No Flask entrypoint found.

`.vercel/output` is Vercel's Build Output API, the "already built, just serve
it" contract. No detection, no build step, no framework preset involved. The
workflow assembles it:

    .vercel/output/config.json     <- vercel-output-config.json
    .vercel/output/static/         <- frontend_flutter/build/web

## Two routing decisions that are not obvious

Both live in `vercel-output-config.json`.

**The SPA fallback.** The route table is: apply headers and continue, then
`handle: filesystem`, then send anything still unmatched to `index.html`. The
filesystem stage is what stops the catch-all swallowing `main.dart.js` --
verified against the real build output, along with canvaskit, the bootstrap and
the favicon, while `/settings` and `/some/deep/route` correctly fall through.
The app routes client-side, so without that fallback a refresh on any route
404s.

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
    cd ..
    mkdir -p .vercel/output
    cp vercel-output-config.json .vercel/output/config.json
    cp -r frontend_flutter/build/web .vercel/output/static
    npx vercel deploy --prebuilt --prod --token=...

# Releasing the Android app

The APK is built by GitHub Actions and attached to a GitHub release. Obtainium
on the phone watches the repository's releases and offers each new one as an
update, so nothing is ever copied to the phone by hand.

## A tag is a release

    git tag v1.1.0
    git push origin v1.1.0

That is the whole procedure. `release-android.yml` runs the analyzer and the
tests, builds a signed arm64 APK, and publishes it as the release `v1.1.0`
with one asset, `Scandy-1.1.0-arm64-v8a.apk`, and release notes generated from
the commit subjects since the previous tag.

The tag *is* the version: `v1.2.3` becomes `versionName 1.2.3` and
`versionCode 10203`. The version line in `pubspec.yaml` is not consulted, so
there is one place to bump and it is the one that has to exist anyway. Two
things follow from the scheme:

- Tags must be exactly `vMAJOR.MINOR.PATCH`, each part at most 99. Anything
  else does not trigger the workflow, and a part over 99 fails it.
- Versions must only go up. Android refuses to install a lower version code
  over a higher one, so a `v1.0.9` cut after `v1.1.0` would build fine and then
  be uninstallable on any phone that already took `v1.1.0`.

## The key has to be the same key

Android will not install an APK over an existing copy of the app unless both
are signed by the same key. So the workflow signs with the *same* keystore the
by-hand builds use -- the one `android/key.properties` points at -- and refuses
to build without it rather than fall back to the debug key, which would produce
a release Obtainium shows forever and can never apply. Lose that keystore and
every phone has to uninstall and start over; it is worth backing up.

## First-time setup

1. Encode the keystore and put it on the clipboard:

       base64 -i /path/to/scandy-upload.jks | pbcopy

2. Add four secrets under GitHub > Settings > Secrets and variables > Actions,
   alongside the Supabase ones the web deploy already has:

       ANDROID_KEYSTORE_BASE64      what is on the clipboard
       ANDROID_KEYSTORE_PASSWORD    storePassword from android/key.properties
       ANDROID_KEY_PASSWORD         keyPassword from the same file
       ANDROID_KEY_ALIAS            keyAlias from the same file (scandy-upload)

3. Push a tag, as above, and watch the Actions tab. The release appears under
   the repository's Releases once the run is green.

4. On the phone, in Obtainium: **Add App**, paste
   `https://github.com/JinWei225/Scandy`, and add. It picks up the latest
   release, installs it, and from then on checks for new ones on its own.

   If a copy of Scandy built by hand is already installed, Obtainium will
   offer the release as an update. It installs cleanly as long as the tag is
   higher than the version on the phone (any tag is higher than a `1.0.0+1`
   local build) and the same keystore signed both.

## Only arm64

`--split-per-abi --target-platform android-arm64`: one APK for the one ABI
the phones this is for actually have. A fat APK carrying armeabi-v7a and
x86_64 as well is nearly three times the size for the sake of ABIs nobody
installs. If another ABI is ever needed, add it to `--target-platform`, and
name the second asset by its ABI too; Obtainium can be told which to prefer
with a filename filter in the app's settings.
