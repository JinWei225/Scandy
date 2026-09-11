-- ============================================================================
-- replace_transaction(): editing across the transfer boundary is atomic.
--
-- The point of the function is what happens when the second half fails, so
-- the interesting case here is a rejected edit: the original rows must still
-- be there afterwards, untouched.
--
-- Rolls back at the end; leaves nothing behind.
-- ============================================================================

\set ON_ERROR_STOP on
begin;

\set uid '44444444-4444-4444-4444-444444444444'

insert into public.signup_allowlist (email, note)
values ('replace-test@scandy.invalid', 'test fixture');

insert into auth.users (id, instance_id, aud, role, email)
values (:'uid', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'replace-test@scandy.invalid');

set local role authenticated;
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

insert into public.accounts (user_id, name, type, initial_balance_cents)
values (:'uid', 'MAE', 'Bank', 100000),
       (:'uid', 'TNG', 'E-Wallet', 0);

-- --- A transfer becomes a different transfer ---------------------------------
do $$
declare
    v_mae uuid := (select id from public.accounts where name = 'MAE');
    v_tng uuid := (select id from public.accounts where name = 'TNG');
    v_leg uuid;
    n int;
begin
    perform public.create_transfer(v_mae, v_tng, 5000, date '2026-09-01');
    select id into v_leg from public.transactions where type = 'income';   -- the TNG leg

    -- Editing from the incoming leg must still rewrite both.
    select count(*) into n from public.replace_transaction(
        v_leg, 'transfer', date '2026-09-02', 7500,
        p_account_id => v_tng, p_to_account => v_mae, p_description => 'Top up');
    if n <> 2 then raise exception 'FAIL: expected 2 new legs, got %', n; end if;

    if (select count(*) from public.transactions) <> 2 then
        raise exception 'FAIL: the old pair was not removed';
    end if;
    if (select count(distinct transfer_group_id) from public.transactions) <> 1 then
        raise exception 'FAIL: the new legs do not share a group';
    end if;
    if not exists (select 1 from public.transactions
                    where type = 'expense' and account_id = v_tng and amount_cents = 7500
                      and occurred_on = date '2026-09-02' and description = 'Top up') then
        raise exception 'FAIL: the new From leg is wrong';
    end if;
    raise notice 'PASS  editing either leg rewrites the whole transfer';
end $$;

-- --- A rejected edit leaves the original pair alone -------------------------
do $$
declare
    v_tng  uuid := (select id from public.accounts where name = 'TNG');
    v_leg  uuid := (select id from public.transactions where type = 'expense');
    before bigint := (select sum(amount_cents) from public.transactions);
begin
    begin
        perform public.replace_transaction(
            v_leg, 'transfer', date '2026-09-03', 100,
            p_account_id => v_tng, p_to_account => v_tng);   -- same account
        raise exception 'FAIL: a self-transfer was accepted';
    exception when check_violation then
        null;   -- expected
    end;

    if (select count(*) from public.transactions) <> 2
    or (select sum(amount_cents) from public.transactions) <> before then
        raise exception 'FAIL: a rejected edit destroyed the original transfer';
    end if;
    raise notice 'PASS  a rejected edit changes nothing';
end $$;

-- --- A transfer becomes a plain expense --------------------------------------
do $$
declare
    v_mae uuid := (select id from public.accounts where name = 'MAE');
    v_leg uuid := (select id from public.transactions where type = 'income');
begin
    perform public.replace_transaction(
        v_leg, 'expense', date '2026-09-04', 1250,
        p_category => 'Food & Drink', p_account_id => v_mae, p_description => 'Lunch');

    if (select count(*) from public.transactions) <> 1 then
        raise exception 'FAIL: expected exactly one row after collapsing a transfer';
    end if;
    if not exists (select 1 from public.transactions
                    where type = 'expense' and transfer_group_id is null
                      and category = 'Food & Drink' and amount_cents = 1250) then
        raise exception 'FAIL: the replacement expense is wrong';
    end if;
    raise notice 'PASS  a transfer collapses into one plain row';
end $$;

-- --- A plain row becomes a transfer -----------------------------------------
do $$
declare
    v_mae uuid := (select id from public.accounts where name = 'MAE');
    v_tng uuid := (select id from public.accounts where name = 'TNG');
    v_row uuid := (select id from public.transactions);
begin
    perform public.replace_transaction(
        v_row, 'transfer', date '2026-09-05', 2000,
        p_account_id => v_mae, p_to_account => v_tng);

    if (select count(*) from public.transactions) <> 2
    or (select count(*) from public.transactions where category = 'Transfer') <> 2 then
        raise exception 'FAIL: the plain row did not become a transfer pair';
    end if;
    raise notice 'PASS  a plain row expands into a transfer';
end $$;

-- --- Somebody else's row does not exist from here ---------------------------
do $$
begin
    begin
        perform public.replace_transaction(
            gen_random_uuid(), 'expense', date '2026-09-06', 100);
        raise exception 'FAIL: an unknown id was accepted';
    exception when no_data_found then
        null;   -- expected
    end;
    raise notice 'PASS  an id that is not yours is simply not found';
end $$;

reset role;
do $$ begin raise notice ''; raise notice 'ALL REPLACE_TRANSACTION CHECKS PASSED'; end $$;
rollback;
