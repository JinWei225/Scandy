-- ============================================================================
-- A record of cloud scans, purely so they can be capped.
--
-- The on-device scanner is free and unlimited. This counts only the fallback,
-- which calls a metered API -- and a metered API behind a public sign-up form
-- is a bill waiting to happen, whether through a bug that retries forever or
-- somebody who finds the app.
--
-- No policies are declared, deliberately. RLS is enabled and nothing grants
-- `authenticated` any access, so a signed-in user can neither read this table
-- nor -- more to the point -- delete rows from it to reset their own cap. The
-- Edge Function reaches it with the service role, which bypasses RLS.
-- ============================================================================

create table public.receipt_scans (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references auth.users on delete cascade,
    created_at timestamptz not null default now()
);

-- The only query run against it: "how many in the last 24 hours, for this user".
create index receipt_scans_user_time_idx
    on public.receipt_scans (user_id, created_at desc);

alter table public.receipt_scans enable row level security;

revoke all on public.receipt_scans from anon, authenticated;
