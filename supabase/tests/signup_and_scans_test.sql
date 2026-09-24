-- ============================================================================
-- Sign-up and the scan cap: the parts of the schema a signed-in person must
-- not be able to reach, and the welcome a new account gets.
--
--   * The allowlist matches however the address is typed.
--   * A Chinese sign-up is seeded with Chinese categories, in order.
--   * receipt_scans, which holds the Edge Function's per-user cap, cannot be
--     read, written or -- above all -- emptied by the user it counts.
--   * The allowlist and the trigger functions are out of reach as well.
--
-- Run with ./supabase/tests/run.sh. Rolled back at the end.
-- ============================================================================

\set ON_ERROR_STOP on
begin;

\set uid_zh '44444444-4444-4444-4444-444444444444'
\set uid_hant '55555555-5555-5555-5555-555555555555'

-- Stored with capitals and a stray space; signed up with neither.
insert into public.signup_allowlist (email, note)
values (' Scan-Test-ZH@Scandy.Invalid', 'test fixture'),
       ('scan-test-hant@scandy.invalid', 'test fixture');

insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data)
values
    (:'uid_zh', '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scan-test-zh@scandy.invalid', '{"locale":"zh-CN"}'),
    (:'uid_hant', '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scan-test-hant@scandy.invalid', '{"locale":"zh-Hant"}');

do $$ begin
    raise notice 'PASS  the allowlist ignores case and surrounding spaces';
end $$;

do $$
declare got text[];
begin
    select array_agg(name order by sort_order) into got
      from public.categories
     where user_id = '44444444-4444-4444-4444-444444444444' and kind = 'expense';
    if got is distinct from array['餐饮', '购物', '交通', '水电杂费', '娱乐', '医疗',
                                  '日用采买', '分期付款', '其他'] then
        raise exception 'FAIL zh seed (expense): %', got;
    end if;

    select array_agg(name order by sort_order) into got
      from public.categories
     where user_id = '44444444-4444-4444-4444-444444444444' and kind = 'income';
    if got is distinct from array['工资', '投资', '礼金', '退款', '其他'] then
        raise exception 'FAIL zh seed (income): %', got;
    end if;

    -- Only the language is read, so a region or script still means Chinese.
    if (select count(*) from public.categories
         where user_id = '55555555-5555-5555-5555-555555555555'
           and name = '餐饮') <> 1 then
        raise exception 'FAIL zh-Hant did not get the Chinese list';
    end if;

    raise notice 'PASS  a Chinese sign-up gets Chinese categories, in order';
end $$;

-- --- The scan cap, as the service role the Edge Function uses ---------------
set local role service_role;
insert into public.receipt_scans (user_id)
select '44444444-4444-4444-4444-444444444444' from generate_series(1, 3);

do $$ begin
    if (select count(*) from public.receipt_scans
         where user_id = '44444444-4444-4444-4444-444444444444'
           and created_at >= now() - interval '24 hours') <> 3 then
        raise exception 'FAIL service role could not count scans';
    end if;
    raise notice 'PASS  the service role records and counts scans';
end $$;
reset role;

-- --- The same table, as the person being counted ----------------------------
set local role authenticated;
select set_config('request.jwt.claims',
                  json_build_object('sub', :'uid_zh', 'role', 'authenticated')::text,
                  true);

do $$
declare
    denied int := 0;
begin
    begin
        perform count(*) from public.receipt_scans;
    exception when insufficient_privilege then denied := denied + 1;
    end;

    begin
        delete from public.receipt_scans;
    exception when insufficient_privilege then denied := denied + 1;
    end;

    begin
        insert into public.receipt_scans (user_id)
        values ('44444444-4444-4444-4444-444444444444');
    exception when insufficient_privilege then denied := denied + 1;
    end;

    if denied <> 3 then
        raise exception 'FAIL receipt_scans: only % of read/delete/insert were refused', denied;
    end if;
    raise notice 'PASS  a user can neither read nor reset their own scan count';
end $$;

do $$
declare
    denied int := 0;
begin
    begin
        perform count(*) from public.signup_allowlist;
    exception when insufficient_privilege then denied := denied + 1;
    end;

    begin
        insert into public.signup_allowlist (email) values ('friend@scandy.invalid');
    exception when insufficient_privilege then denied := denied + 1;
    end;

    if denied <> 2 then
        raise exception 'FAIL signup_allowlist: a user could read or extend it';
    end if;
    raise notice 'PASS  a user can neither read nor extend the allowlist';
end $$;

do $$ begin
    -- Security definer, so calling one directly would run as its owner.
    if has_function_privilege('authenticated', 'public.handle_new_user()', 'execute')
       or has_function_privilege('authenticated', 'public.enforce_signup_allowlist()', 'execute')
       or has_function_privilege('anon', 'public.handle_new_user()', 'execute') then
        raise exception 'FAIL a trigger function is callable by a signed-in user';
    end if;
    raise notice 'PASS  trigger functions are not callable directly';
end $$;

reset role;

-- --- Leaving -----------------------------------------------------------------
delete from auth.users where id = :'uid_zh';

do $$ begin
    if exists (select 1 from public.receipt_scans
                where user_id = '44444444-4444-4444-4444-444444444444') then
        raise exception 'FAIL a deleted user''s scans were left behind';
    end if;
    raise notice 'PASS  deleting a user takes their scan history with them';
end $$;

do $$ begin raise notice ''; raise notice 'ALL SIGNUP AND SCAN CHECKS PASSED'; end $$;

rollback;
