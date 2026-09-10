-- ============================================================================
-- Let a user actually be deleted.
--
-- forbid_deleting_last_category() exists so nobody can empty a kind and end up
-- with a transaction form that has nothing to choose. But it also fires during
-- the ON DELETE CASCADE from auth.users: deleting an account removes that
-- user's categories one at a time, and the moment the cascade reaches the last
-- expense category the trigger raises and takes the whole delete down with it.
--
--     delete from auth.users where email = '...';
--     ERROR:  Cannot delete the last expense category
--
-- So account deletion -- from the dashboard, from the admin API, from anywhere
-- -- simply failed, with an error naming something the caller never mentioned.
--
-- The rule only ever meant to protect a *live* user from emptying their own
-- list. If the owner is already gone, there is no list left to protect, so the
-- trigger stands aside and lets the cascade finish.
-- ============================================================================

-- SECURITY DEFINER, where the original was INVOKER, and that change is the
-- whole reason this needs care. The check below reads auth.users, and the
-- `authenticated` role has no SELECT there -- as INVOKER, every ordinary
-- category delete would fail with "permission denied for table users", which
-- is far worse than the bug being fixed.
--
-- What makes that safe here: the function takes no arguments, reads exactly one
-- row by primary key, writes nothing, and cannot be called directly because
-- EXECUTE is revoked below. Combined with `set search_path = ''` it has no
-- surface to abuse.
create or replace function public.forbid_deleting_last_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- The parent row is deleted before its cascades run, so an absent user
    -- here means "this category is going away with its owner".
    if not exists (select 1 from auth.users where id = old.user_id) then
        return old;
    end if;

    if (select count(*) from public.categories
         where user_id = old.user_id and kind = old.kind) <= 1 then
        raise exception 'Cannot delete the last % category', old.kind
            using errcode = 'check_violation';
    end if;

    return old;
end;
$$;

-- create or replace keeps the grants from the original definition, and this
-- function still needs none: the trigger invokes it regardless.
revoke execute on function public.forbid_deleting_last_category()
    from public, anon, authenticated;
