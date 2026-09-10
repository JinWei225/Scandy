-- ============================================================================
-- Seed a new account's categories in the language the person signed up in.
--
-- The app is translated, but categories are rows, not strings: a Chinese
-- reader who signed up before this would land on a Home screen whose every
-- transaction was filed under "Groceries" and "Transport". Renaming all
-- fourteen by hand is not a welcome.
--
-- The sign-up form now sends the display language alongside the display name,
-- and this reads it. Anything that is not 'zh' -- including a form that sends
-- nothing, which is every account created before today -- gets the English
-- list exactly as before.
--
-- The names are not a translation table: nothing joins on them and nothing
-- looks them up. They are simply the rows a Chinese account starts with, and
-- renaming one afterwards works the same as it always did.
--
-- Replaces the function from 20260910130300_new_user.sql. The trigger is
-- unchanged and keeps pointing at it, so there is nothing to re-create.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    -- Only the language matters here; a 'zh-Hant' or 'zh-CN' still means the
    -- Chinese list, and the app only ships Simplified.
    wants_chinese boolean :=
        left(coalesce(new.raw_user_meta_data ->> 'locale', ''), 2) = 'zh';
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
    select new.id, 'expense', name
    from unnest(
        case when wants_chinese then array[
            '餐饮',
            '购物',
            '交通',
            '水电杂费',
            '娱乐',
            '医疗',
            '日用采买',
            '分期付款',
            '其他'
        ] else array[
            'Food & Drink',
            'Shopping',
            'Transport',
            'Bills & Utilities',
            'Entertainment',
            'Health',
            'Groceries',
            'Installments',
            'Other'
        ] end
    ) as name;

    insert into public.categories (user_id, kind, name)
    select new.id, 'income', name
    from unnest(
        case when wants_chinese then array[
            '工资',
            '投资',
            '礼金',
            '退款',
            '其他'
        ] else array[
            'Salary',
            'Investments',
            'Gifts',
            'Refunds',
            'Other'
        ] end
    ) as name;

    return new;
end;
$$;

-- Same lockdown as 20260910130400: the function is only ever meant to be
-- reached by the trigger, and `create or replace` resets its grants.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
