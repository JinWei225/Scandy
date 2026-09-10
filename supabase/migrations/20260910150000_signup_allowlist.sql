-- ============================================================================
-- Who is allowed to create an account.
--
-- The web app is on a public URL and the repository is public, so sign-up has
-- to be closed to be closed. Not because a stranger could see anything -- row
-- level security means they could not -- but because every account shares one
-- Gemini quota. On the free tier, an unknown person's scan is a scan your mum
-- does not get.
--
-- A table rather than a list baked into this file, because the reason the list
-- exists is that it changes: showing the app to somebody means adding them,
-- and that should be one row in the dashboard rather than a migration, a push
-- and a deploy while they stand there waiting.
--
--     insert into public.signup_allowlist (email, note)
--     values ('them@example.com', 'demo, 10 Sep');
--
-- Removing a row does not remove an account that already exists. To take
-- somebody's access away, delete the user -- which works, since
-- 20260910130500.
-- ============================================================================

create table public.signup_allowlist (
    email    text primary key,
    note     text,
    added_at timestamptz not null default now()
);

-- Nobody signed in has any business reading this, let alone adding to it. No
-- policies at all, so only the service role and the dashboard can touch it.
alter table public.signup_allowlist enable row level security;
revoke all on public.signup_allowlist from anon, authenticated;

-- Case-insensitively, because nobody types their own address the same way
-- twice and 'Nefflymicn@Gmail.com' is the same person.
create unique index signup_allowlist_email_idx
    on public.signup_allowlist (lower(btrim(email)));

create function public.enforce_signup_allowlist()
returns trigger
language plpgsql
security definer   -- the table is unreadable to the role signing up, by design
set search_path = ''
as $$
begin
    if not exists (
        select 1 from public.signup_allowlist
         where lower(btrim(email)) = lower(btrim(new.email))
    ) then
        -- Reaches the sign-up screen through friendlyAuthError(), so it is
        -- written for the person reading it rather than for a log.
        raise exception 'Scandy is invite only at the moment.'
            using errcode = 'check_violation';
    end if;
    return new;
end;
$$;

revoke execute on function public.enforce_signup_allowlist()
    from public, anon, authenticated;

-- BEFORE INSERT, so a refused sign-up leaves no half-made user behind.
create trigger check_signup_allowlist
    before insert on auth.users
    for each row execute function public.enforce_signup_allowlist();

-- The owner. Everyone else gets added by hand, as and when.
insert into public.signup_allowlist (email, note)
values ('nefflymicn@gmail.com', 'owner');
