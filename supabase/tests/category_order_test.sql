-- ============================================================================
-- Categories come back in creation order: the starter list as seeded, then
-- each addition at the bottom, and a rename keeps its place.
--
-- Run with ./supabase/tests/run.sh. Rolled back at the end.
-- ============================================================================

\set ON_ERROR_STOP on
begin;

\set uid '33333333-3333-3333-3333-333333333333'

insert into public.signup_allowlist (email, note)
values ('order-test@scandy.invalid', 'test fixture');

insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data)
values (:'uid', '00000000-0000-0000-0000-000000000000', 'authenticated',
        'authenticated', 'order-test@scandy.invalid', '{}');

set local role authenticated;
select set_config('request.jwt.claims',
                  json_build_object('sub', :'uid', 'role', 'authenticated')::text,
                  true);

do $$
declare got text[];
begin
    select array_agg(name order by sort_order) into got
      from public.categories where kind = 'expense';
    if got <> array['Food & Drink', 'Shopping', 'Transport', 'Bills & Utilities',
                    'Entertainment', 'Health', 'Groceries', 'Installments', 'Other'] then
        raise exception 'FAIL seed order: %', got;
    end if;

    select array_agg(name order by sort_order) into got
      from public.categories where kind = 'income';
    if got <> array['Salary', 'Investments', 'Gifts', 'Refunds', 'Other'] then
        raise exception 'FAIL seed order (income): %', got;
    end if;

    raise notice 'PASS  a new account''s categories are in seed order';
end $$;

-- Lowercase and "A..." would both sort above "Other" by name; neither should.
insert into public.categories (user_id, kind, name)
values (:'uid', 'expense', 'zakat');
insert into public.categories (user_id, kind, name)
values (:'uid', 'expense', 'Allowance');

do $$
declare got text[];
begin
    select array_agg(name order by sort_order) into got
      from public.categories where kind = 'expense';
    if got[9:11] <> array['Other', 'zakat', 'Allowance'] then
        raise exception 'FAIL additions should follow in creation order: %', got;
    end if;
    raise notice 'PASS  added categories go to the bottom, in the order added';
end $$;

do $$
declare got text[];
begin
    perform public.rename_category('expense', 'Shopping', 'Aaa Shopping');
    select array_agg(name order by sort_order) into got
      from public.categories where kind = 'expense';
    if got[2] <> 'Aaa Shopping' then
        raise exception 'FAIL a rename should keep its place: %', got;
    end if;
    raise notice 'PASS  a renamed category keeps its place';
end $$;

rollback;
