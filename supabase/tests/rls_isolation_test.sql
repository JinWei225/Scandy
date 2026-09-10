-- ============================================================================
-- Proof that two users cannot reach each other's ledgers.
--
-- Run against a local stack:
--     supabase db reset
--     psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '"')" \
--          -v ON_ERROR_STOP=1 -f supabase/tests/rls_isolation_test.sql
--
-- The whole thing runs inside a transaction that is rolled back at the end, so
-- it leaves no users, no rows and no sequence drift behind. Any failed
-- assertion raises, and ON_ERROR_STOP turns that into a non-zero exit code --
-- so this is usable as a CI gate, not just something to read.
--
-- Impersonation works the way PostgREST does it: become the `authenticated`
-- role and set the JWT claims that auth.uid() reads. No real sign-in needed.
-- ============================================================================

\set ON_ERROR_STOP on
begin;

\set uid_a '11111111-1111-1111-1111-111111111111'
\set uid_b '22222222-2222-2222-2222-222222222222'

-- --- Setup, as the migration role ------------------------------------------
-- Inserting into auth.users also exercises the on_auth_user_created trigger.
insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data)
values
    (:'uid_a', '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'rls-test-a@scandy.invalid', '{"display_name":"Jin Wei"}'),
    (:'uid_b', '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'rls-test-b@scandy.invalid', '{}');

do $$
declare n int;
begin
    select count(*) into n from public.profiles;
    if n <> 2 then
        raise exception 'FAIL trigger: expected 2 profiles, got %', n;
    end if;

    select count(*) into n from public.categories where user_id = '11111111-1111-1111-1111-111111111111';
    if n <> 14 then
        raise exception 'FAIL trigger: expected 14 seeded categories, got %', n;
    end if;

    -- The fallback path: no display_name in metadata, so the email local part.
    if (select display_name from public.profiles
         where id = '22222222-2222-2222-2222-222222222222') <> 'rls-test-b' then
        raise exception 'FAIL trigger: display_name fallback did not fire';
    end if;

    raise notice 'PASS  signup trigger seeds a profile and 14 categories';
end $$;

-- --- User A writes a ledger -------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

insert into public.accounts (user_id, name, type, initial_balance_cents)
values ('11111111-1111-1111-1111-111111111111', 'MAE', 'Bank', 648434);

insert into public.transactions
    (user_id, occurred_on, description, amount_cents, category, account_id, type)
values ('11111111-1111-1111-1111-111111111111', date '2026-09-10', 'Bread', 720,
        'Food & Drink', (select id from public.accounts where name = 'MAE'), 'expense');

do $$
declare n int;
begin
    select count(*) into n from public.transactions;
    if n <> 1 then raise exception 'FAIL: A should see 1 transaction, saw %', n; end if;
    raise notice 'PASS  A sees its own row';
end $$;

reset role;

-- --- User B: the actual test ------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare n int;
begin
    select count(*) into n from public.transactions;
    if n <> 0 then raise exception 'FAIL leak: B can read % of A''s transactions', n; end if;

    select count(*) into n from public.accounts;
    if n <> 0 then raise exception 'FAIL leak: B can read % of A''s accounts', n; end if;

    -- The view is the subtle one. Without security_invoker = true it evaluates
    -- RLS as its owner and hands B every balance in the database.
    select count(*) into n from public.account_balances;
    if n <> 0 then raise exception 'FAIL leak: B can read % account balances', n; end if;

    select count(*) into n from public.categories;
    if n <> 14 then raise exception 'FAIL: B should see only its own 14 categories, saw %', n; end if;

    raise notice 'PASS  B sees none of A''s accounts, transactions or balances';
end $$;

do $$
declare n int;
begin
    -- Writes aimed at A's rows must be no-ops, not errors: RLS filters them
    -- out before the UPDATE or DELETE ever matches.
    update public.transactions set amount_cents = 1 where description = 'Bread';
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FAIL: B updated % of A''s rows', n; end if;

    delete from public.transactions;
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FAIL: B deleted % of A''s rows', n; end if;

    raise notice 'PASS  B cannot update or delete A''s rows';
end $$;

do $$
begin
    -- The one a `using`-only policy would let through: B stamping a row with
    -- A's user_id. It must be refused by `with check`.
    insert into public.transactions (user_id, occurred_on, description, amount_cents, type)
    values ('11111111-1111-1111-1111-111111111111', date '2026-09-10', 'forged', 100, 'expense');
    raise exception 'FAIL: B wrote a row into A''s ledger';
exception
    when insufficient_privilege then
        raise notice 'PASS  a forged user_id on insert is rejected';
end $$;

reset role;

-- --- A's ledger is untouched ------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
declare n int; v bigint;
begin
    select count(*) into n from public.transactions;
    if n <> 1 then raise exception 'FAIL: A should still have exactly 1 row, has %', n; end if;

    -- 6484.34 opening, less 7.20 spent.
    select balance_cents into v from public.account_balances b
      join public.accounts a on a.id = b.account_id where a.name = 'MAE';
    if v <> 647714 then raise exception 'FAIL balance: expected 647714 cents, got %', v; end if;

    raise notice 'PASS  A''s ledger survived intact, balance arithmetic correct';
end $$;

-- --- create_transfer moves money without changing the total -----------------
insert into public.accounts (user_id, name, type, initial_balance_cents)
values ('11111111-1111-1111-1111-111111111111', 'TNG E-wallet', 'E-Wallet', 411185);

do $$
declare n int; total bigint;
begin
    perform public.create_transfer(
        (select id from public.accounts where name = 'MAE'),
        (select id from public.accounts where name = 'TNG E-wallet'),
        5000::bigint, date '2026-09-10');

    select count(*) into n from public.transactions where transfer_group_id is not null;
    if n <> 2 then raise exception 'FAIL transfer: expected 2 legs, got %', n; end if;

    if (select count(distinct transfer_group_id) from public.transactions
         where transfer_group_id is not null) <> 1 then
        raise exception 'FAIL transfer: legs do not share one group id';
    end if;

    -- A transfer moves money; it must not create or destroy any.
    select sum(balance_cents) into total from public.account_balances;
    if total <> 647714 + 411185 then
        raise exception 'FAIL transfer: total changed to %', total;
    end if;

    raise notice 'PASS  create_transfer writes one paired group and conserves the total';
end $$;

do $$
begin
    perform public.create_transfer(
        (select id from public.accounts where name = 'MAE'),
        (select id from public.accounts where name = 'MAE'),
        100::bigint, date '2026-09-10');
    raise exception 'FAIL: a self-transfer was allowed';
exception
    when check_violation then
        raise notice 'PASS  a self-transfer is refused';
end $$;

-- --- rename_category reaches history as well as the category ----------------
do $$
begin
    perform public.rename_category('expense', 'Food & Drink', 'Makan');

    if (select category from public.transactions where description = 'Bread') <> 'Makan' then
        raise exception 'FAIL rename: history was not cascaded';
    end if;
    if exists (select 1 from public.categories where name = 'Food & Drink') then
        raise exception 'FAIL rename: the old category still exists';
    end if;

    raise notice 'PASS  rename_category cascades into transaction history';
end $$;

do $$
begin
    perform public.rename_category('expense', 'Makan', 'shopping');
    raise exception 'FAIL: a case-insensitive duplicate was allowed';
exception
    when unique_violation then
        raise notice 'PASS  a case-insensitive duplicate category is refused';
end $$;

-- --- the last category is protected, but only for a live user ---------------
do $$
declare n int;
begin
    delete from public.categories
     where kind = 'expense'
       and id <> (select id from public.categories where kind = 'expense' limit 1);
    select count(*) into n from public.categories where kind = 'expense';
    if n <> 1 then raise exception 'FAIL: setup left % expense categories', n; end if;

    begin
        delete from public.categories where kind = 'expense';
        raise exception 'FAIL: the last expense category was deleted';
    exception
        when check_violation then
            raise notice 'PASS  the last category of a kind cannot be deleted';
    end;
end $$;

reset role;

-- --- ...and that guard must not block deleting the account ------------------
--
-- Deleting a user cascades into categories one row at a time. Before the fix
-- in 20260910130500, the cascade hit that same guard on the last one and took
-- the whole delete down with it -- so accounts simply could not be removed.
do $$
declare leftover int;
begin
    delete from auth.users where id = '22222222-2222-2222-2222-222222222222';

    select count(*) into leftover from public.categories
     where user_id = '22222222-2222-2222-2222-222222222222';
    if leftover <> 0 then
        raise exception 'FAIL: % categories survived the user', leftover;
    end if;
    if exists (select 1 from public.profiles
                where id = '22222222-2222-2222-2222-222222222222') then
        raise exception 'FAIL: the profile survived the user';
    end if;

    raise notice 'PASS  a user can be deleted, and everything of theirs goes with them';
end $$;

do $$ begin raise notice ''; raise notice 'ALL CHECKS PASSED'; end $$;

rollback;
