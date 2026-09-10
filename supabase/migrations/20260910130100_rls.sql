-- ============================================================================
-- Row level security: the entire separation guarantee.
--
-- Every policy is the same shape -- you may touch a row if it is yours -- and
-- every one carries BOTH `using` and `with check`. The distinction matters:
--
--   using      filters what SELECT / UPDATE / DELETE can see
--   with check validates what INSERT / UPDATE tries to write
--
-- A policy with only `using` lets an authenticated user INSERT a row stamped
-- with somebody else's user_id. They could not then read it back, but they
-- would have written into another person's ledger, which is exactly the
-- failure this migration exists to prevent. The test in
-- supabase/tests/rls_isolation_test.sql asserts that case explicitly.
--
-- `to authenticated` keeps the anon role out entirely: a signed-out visitor
-- matches no policy and therefore sees nothing, rather than relying on
-- auth.uid() happening to be null.
-- ============================================================================

alter table public.profiles      enable row level security;
alter table public.accounts      enable row level security;
alter table public.categories    enable row level security;
alter table public.transactions  enable row level security;
alter table public.subscriptions enable row level security;

-- profiles keys on `id` rather than `user_id`: the row IS the user.
create policy profiles_own_row on public.profiles
    for all to authenticated
    using (id = (select auth.uid()))
    with check (id = (select auth.uid()));

create policy accounts_own_rows on public.accounts
    for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

create policy categories_own_rows on public.categories
    for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

create policy transactions_own_rows on public.transactions
    for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

create policy subscriptions_own_rows on public.subscriptions
    for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

-- `(select auth.uid())` rather than a bare `auth.uid()` is not a style choice:
-- the subselect is evaluated once per statement instead of once per row, which
-- is the difference between an index scan and a sequential scan on the
-- transactions table as it grows.

-- ---------------------------------------------------------------------------
-- Deleting a category must not be able to empty a kind, or the transaction
-- form opens with nothing to choose. This lived in delete_category() in
-- Python; as a trigger it holds no matter which client issues the DELETE.
-- ---------------------------------------------------------------------------
create function public.forbid_deleting_last_category()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if (select count(*) from public.categories
         where user_id = old.user_id and kind = old.kind) <= 1 then
        raise exception 'Cannot delete the last % category', old.kind
            using errcode = 'check_violation';
    end if;
    return old;
end;
$$;

create trigger categories_keep_at_least_one
    before delete on public.categories
    for each row execute function public.forbid_deleting_last_category();
