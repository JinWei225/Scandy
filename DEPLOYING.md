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
