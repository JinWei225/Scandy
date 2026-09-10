-- ============================================================================
-- record_due_subscriptions(): the month arithmetic, against pinned dates.
--
-- This is the function with the most places to be subtly wrong -- a gap of
-- several months, a day-31 charge in February, the current month before its
-- day has arrived, and the 24-month catch-up cap. Every case below was a
-- deliberate decision in backend/main.py's _unrecorded_months(), so every one
-- gets an assertion here.
--
-- Rolls back at the end; leaves nothing behind.
-- ============================================================================

\set ON_ERROR_STOP on
begin;

\set uid '33333333-3333-3333-3333-333333333333'

insert into auth.users (id, instance_id, aud, role, email)
values (:'uid', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'subs-test@scandy.invalid');

set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

insert into public.accounts (user_id, name, type, initial_balance_cents)
values (:'uid', 'TNG E-wallet', 'E-Wallet', 0);

-- --- Never recorded, and this month's day has passed -------------------------
do $$
declare n int; d date;
begin
    insert into public.subscriptions (user_id, name, amount_cents, day_of_month, account_id)
    values ('33333333-3333-3333-3333-333333333333', 'iCloud Storage', 390, 3,
            (select id from public.accounts limit 1));

    select count(*) into n from public.record_due_subscriptions(date '2026-09-10');
    if n <> 1 then raise exception 'FAIL: expected 1 charge, got %', n; end if;

    select occurred_on into d from public.transactions order by created_at desc limit 1;
    if d <> date '2026-09-03' then raise exception 'FAIL: charged on % not 2026-09-03', d; end if;

    -- A subscription only just added must not back-fill history it never had.
    if (select count(*) from public.transactions) <> 1 then
        raise exception 'FAIL: back-filled charges that never happened';
    end if;

    raise notice 'PASS  a new subscription charges once, for this month only';
end $$;

-- --- Idempotency -------------------------------------------------------------
do $$
declare n int;
begin
    select count(*) into n from public.record_due_subscriptions(date '2026-09-10');
    if n <> 0 then raise exception 'FAIL: re-running created % duplicate charges', n; end if;
    raise notice 'PASS  running it again the same day changes nothing';
end $$;

-- --- The day has not arrived yet ---------------------------------------------
do $$
declare n int;
begin
    insert into public.subscriptions (user_id, name, amount_cents, day_of_month)
    values ('33333333-3333-3333-3333-333333333333', 'Not due yet', 100, 25);

    select count(*) into n from public.record_due_subscriptions(date '2026-09-10');
    if n <> 0 then raise exception 'FAIL: charged % before the due day', n; end if;

    if (select last_recorded_date from public.subscriptions where name = 'Not due yet') is not null then
        raise exception 'FAIL: marked as recorded without charging';
    end if;
    raise notice 'PASS  nothing is charged before its day of the month arrives';
end $$;

-- --- A gap of several months is filled in, month by month --------------------
do $$
declare n int;
begin
    insert into public.subscriptions
        (user_id, name, amount_cents, day_of_month, last_recorded_date)
    values ('33333333-3333-3333-3333-333333333333', 'Tunetalk', 2000, 6, date '2026-06-06');

    select count(*) into n from public.record_due_subscriptions(date '2026-09-10');
    if n <> 3 then raise exception 'FAIL: expected July/Aug/Sep = 3 charges, got %', n; end if;

    if not exists (select 1 from public.transactions
                    where description = 'Subscription: Tunetalk' and occurred_on = date '2026-07-06')
    or not exists (select 1 from public.transactions
                    where description = 'Subscription: Tunetalk' and occurred_on = date '2026-08-06')
    or not exists (select 1 from public.transactions
                    where description = 'Subscription: Tunetalk' and occurred_on = date '2026-09-06') then
        raise exception 'FAIL: the gap was not filled month by month';
    end if;
    raise notice 'PASS  a three-month gap produces three separate charges';
end $$;

-- --- Day 31 in a 28-day month ------------------------------------------------
do $$
declare n int;
begin
    insert into public.subscriptions
        (user_id, name, amount_cents, day_of_month, last_recorded_date)
    values ('33333333-3333-3333-3333-333333333333', 'Rent', 50000, 31, date '2026-01-31');

    -- Per-subscription, not the function's total: one call catches up every
    -- subscription this user has, and the fixtures above are still live.
    perform public.record_due_subscriptions(date '2026-03-31');
    select count(*) into n from public.transactions
     where description = 'Subscription: Rent';
    if n <> 2 then raise exception 'FAIL: expected Feb + Mar for Rent, got %', n; end if;

    -- 2026 is not a leap year, so a day-31 charge lands on the 28th.
    if not exists (select 1 from public.transactions
                    where description = 'Subscription: Rent' and occurred_on = date '2026-02-28') then
        raise exception 'FAIL: February was not clamped to the 28th';
    end if;
    raise notice 'PASS  a day-31 charge clamps to the length of the month';
end $$;

-- --- The 24-month catch-up cap -----------------------------------------------
do $$
declare n int; earliest date;
begin
    insert into public.subscriptions
        (user_id, name, amount_cents, day_of_month, last_recorded_date)
    values ('33333333-3333-3333-3333-333333333333', 'Ancient', 100, 15, date '2020-01-15');

    perform public.record_due_subscriptions(date '2026-09-20');
    select count(*) into n from public.transactions
     where description = 'Subscription: Ancient';
    if n <> 24 then raise exception 'FAIL: expected the 24-month cap, got %', n; end if;

    -- The cap keeps the most recent months, not the oldest.
    select min(occurred_on) into earliest from public.transactions
     where description = 'Subscription: Ancient';
    if earliest <> date '2024-10-15' then
        raise exception 'FAIL: cap kept the wrong end of the range (earliest %)', earliest;
    end if;
    raise notice 'PASS  a long gap is capped at 24 months, keeping the recent ones';
end $$;

-- --- The charges actually move the balance -----------------------------------
do $$
declare v bigint;
begin
    select balance_cents into v from public.account_balances b
      join public.accounts a on a.id = b.account_id where a.name = 'TNG E-wallet';
    -- Only iCloud carries an account_id; the rest were left unassigned.
    if v <> -390 then raise exception 'FAIL: expected -390 cents, got %', v; end if;
    raise notice 'PASS  recorded charges show up in the account balance';
end $$;

reset role;
do $$ begin raise notice ''; raise notice 'ALL SUBSCRIPTION CHECKS PASSED'; end $$;
rollback;
