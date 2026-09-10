-- ============================================================================
-- The four pieces of real logic from backend/main.py, moved next to the data.
--
-- Everything here runs as SECURITY INVOKER, so row level security still
-- applies inside these functions. None of them can reach another user's rows
-- even if called with hand-crafted arguments; they simply see nothing.
--
-- `set search_path = ''` on every function is why each name below is schema
-- qualified. Without it, a role that can create objects could shadow an
-- unqualified name and change what these functions resolve to.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- account_balances -- was get_account_balances()
--
-- security_invoker = true is load bearing. A Postgres view normally evaluates
-- the underlying tables' RLS as its OWNER, which for a Supabase migration is a
-- superuser -- so without this flag this view would happily hand every user
-- everybody's balances, no matter how correct the table policies are.
-- ---------------------------------------------------------------------------
create view public.account_balances
with (security_invoker = true) as
select
    a.id                    as account_id,
    a.user_id,
    a.initial_balance_cents,
    a.initial_balance_cents + coalesce(sum(
        case when t.type = 'income' then t.amount_cents else -t.amount_cents end
    ), 0)                   as balance_cents,
    count(t.id)             as transaction_count
from public.accounts a
-- LEFT so an account with no transactions still reports its opening balance.
left join public.transactions t on t.account_id = a.id
group by a.id, a.user_id, a.initial_balance_cents;

-- ---------------------------------------------------------------------------
-- create_transfer -- was create_transfer_transactions() / _insert_transfer_pair()
--
-- Both legs in one statement, so a failure leaves neither. The old Python
-- opened a connection, inserted two rows and committed; anything that went
-- wrong between the inserts left a half transfer behind.
-- ---------------------------------------------------------------------------
create function public.create_transfer(
    p_from_account  uuid,
    p_to_account    uuid,
    p_amount_cents  bigint,
    p_occurred_on   date,
    p_occurred_at   time default '00:00:00',
    p_description   text default null
)
returns setof public.transactions
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_group uuid := gen_random_uuid();
    v_desc  text := coalesce(nullif(btrim(coalesce(p_description, '')), ''), 'Transfer');
begin
    if p_amount_cents is null or p_amount_cents <= 0 then
        raise exception 'Transfer amount must be more than zero'
            using errcode = 'check_violation';
    end if;

    -- Not in the Python version, which would happily write a pair that netted
    -- to nothing against a single account. There is no reading of that as
    -- anything but a mistake.
    if p_from_account = p_to_account then
        raise exception 'Cannot transfer an account to itself'
            using errcode = 'check_violation';
    end if;

    return query
    insert into public.transactions
        (user_id, occurred_on, occurred_at, description, amount_cents,
         category, account_id, type, transfer_group_id)
    values
        ((select auth.uid()), p_occurred_on, p_occurred_at, v_desc, p_amount_cents,
         'Transfer', p_from_account, 'expense', v_group),
        ((select auth.uid()), p_occurred_on, p_occurred_at, v_desc, p_amount_cents,
         'Transfer', p_to_account,   'income',  v_group)
    returning *;
end;
$$;

-- ---------------------------------------------------------------------------
-- rename_category -- was rename_category()
--
-- The rename has to reach three places at once: the category row, the history
-- that refers to it by name, and any recurring charge that does. Doing it in
-- one function means it cannot half-happen.
-- ---------------------------------------------------------------------------
create function public.rename_category(
    p_kind     text,
    p_old_name text,
    p_new_name text
)
returns setof public.categories
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_old text := btrim(coalesce(p_old_name, ''));
    v_new text := btrim(coalesce(p_new_name, ''));
    v_id  uuid;
begin
    if p_kind not in ('expense', 'income') then
        raise exception 'Category type must be expense or income'
            using errcode = 'check_violation';
    end if;

    select id into v_id
      from public.categories
     where user_id = (select auth.uid()) and kind = p_kind and name = v_old;

    if v_id is null then
        raise exception 'Category % not found', v_old using errcode = 'no_data_found';
    end if;

    -- The remaining validations (blank, over 40 characters, the reserved word
    -- 'Transfer', and case-insensitive collision) are table constraints, so
    -- this UPDATE raises on its own if the new name breaks any of them.
    update public.categories set name = v_new where id = v_id;

    -- Cascade. `type = p_kind` mirrors the old WHERE clause: an expense
    -- category rename must not touch an income row that happens to share a name.
    update public.transactions
       set category = v_new
     where user_id = (select auth.uid()) and category = v_old and type = p_kind;

    -- Subscriptions are expenses only, as in the Python.
    if p_kind = 'expense' then
        update public.subscriptions
           set category = v_new
         where user_id = (select auth.uid()) and category = v_old;
    end if;

    return query
        select * from public.categories
         where user_id = (select auth.uid()) order by kind, name;
end;
$$;

-- ---------------------------------------------------------------------------
-- record_due_subscriptions -- was check_and_record_subscriptions()
--                              plus _unrecorded_months()
--
-- Idempotent: it works out what is owed from last_recorded_date, so calling it
-- twice in a row creates nothing the second time. The old version held a
-- process-wide Python lock to stop two clients double-charging, which only
-- worked because there was exactly one server process. `for update` below is
-- the real thing: concurrent callers queue on the subscription row itself.
-- ---------------------------------------------------------------------------
-- p_today exists so the month arithmetic can be tested against pinned dates
-- instead of drifting with the calendar -- the same reason MonthSummary.forMonth
-- takes `now` as a parameter in the Flutter code. Clients call this with no
-- arguments. Passing a date only ever affects the caller's own ledger, which
-- RLS already confines, so it is not a privilege worth guarding.
create function public.record_due_subscriptions(p_today date default current_date)
returns setof public.transactions
language plpgsql
security invoker
set search_path = ''
as $$
declare
    -- Matches MAX_CATCHUP_MONTHS in backend/main.py.
    c_max_catchup constant int := 24;

    v_today       date := p_today;
    v_this_month  date := date_trunc('month', p_today)::date;
    v_sub         public.subscriptions%rowtype;
    v_start_month date;
    v_month       date;
    v_due         date;
    v_due_day     int;
    v_last_day    int;
begin
    for v_sub in
        select * from public.subscriptions
         where user_id = (select auth.uid())
         order by id
         for update              -- serialises concurrent catch-up runs
    loop
        if v_sub.last_recorded_date is null then
            -- Never recorded: start at this month. Back-filling a subscription
            -- that was only just added would invent charges that never happened.
            v_start_month := v_this_month;
        elsif date_trunc('month', v_sub.last_recorded_date)::date >= v_this_month then
            continue;            -- already recorded for this month
        else
            v_start_month := (date_trunc('month', v_sub.last_recorded_date)
                              + interval '1 month')::date;
        end if;

        -- Cap the catch-up, keeping the most RECENT months: after a long gap
        -- those are the ones still worth recording.
        if v_start_month < (v_this_month - make_interval(months => c_max_catchup - 1))::date then
            v_start_month := (v_this_month - make_interval(months => c_max_catchup - 1))::date;
        end if;

        for v_month in
            select d::date from generate_series(v_start_month, v_this_month, interval '1 month') d
        loop
            -- Clamp to the month's length, so a day-31 subscription still
            -- charges in February and the date is always real.
            v_last_day := extract(day from (v_month + interval '1 month - 1 day'))::int;
            v_due_day  := least(v_sub.day_of_month, v_last_day);
            v_due      := make_date(extract(year from v_month)::int,
                                    extract(month from v_month)::int,
                                    v_due_day);

            -- A month that has fully elapsed is owed outright; the current one
            -- only once its day has actually arrived.
            if v_month = v_this_month and v_today < v_due then
                continue;
            end if;

            return query
            insert into public.transactions
                (user_id, occurred_on, occurred_at, description, amount_cents,
                 category, account_id, type)
            values
                ((select auth.uid()), v_due, '00:00:00',
                 'Subscription: ' || v_sub.name, v_sub.amount_cents,
                 v_sub.category, v_sub.account_id, 'expense')
            returning *;

            -- The due date just recorded, not "today": this field means "the
            -- last month this was auto-recorded", and storing the real date is
            -- what lets the next run work out where it left off.
            update public.subscriptions
               set last_recorded_date = v_due
             where id = v_sub.id;
        end loop;
    end loop;
end;
$$;
