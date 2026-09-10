-- ============================================================================
-- What happens the moment somebody signs up.
--
-- Without this, a new account opens on a transaction form with an empty
-- category dropdown and no profile row -- which is the first thing your mum
-- would see. The seed list is _DEFAULT_CATEGORIES from backend/main.py.
--
-- SECURITY DEFINER is required and is the one place in this schema that needs
-- it: the trigger fires inside Supabase's signup transaction, before the new
-- user has a session, so auth.uid() is null and RLS would reject every insert.
-- It is scoped as tightly as possible -- it only ever writes rows keyed to
-- new.id, the user being created, and it takes no arguments from a caller.
-- ============================================================================

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, display_name)
    values (
        new.id,
        -- Supabase puts whatever the sign-up form sent in raw_user_meta_data.
        -- Falling back to the local part of the email means the greeting is
        -- never blank, even for an account created without a name.
        coalesce(
            nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
            split_part(new.email, '@', 1)
        )
    );

    insert into public.categories (user_id, kind, name)
    select new.id, 'expense', name from unnest(array[
        'Food & Drink',
        'Shopping',
        'Transport',
        'Bills & Utilities',
        'Entertainment',
        'Health',
        'Groceries',
        'Installments',
        'Other'
    ]) as name;

    insert into public.categories (user_id, kind, name)
    select new.id, 'income', name from unnest(array[
        'Salary',
        'Investments',
        'Gifts',
        'Refunds',
        'Other'
    ]) as name;

    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
