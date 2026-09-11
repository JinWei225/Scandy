-- ============================================================================
-- replace_transaction -- editing a row that is, or becomes, a transfer.
--
-- A transfer is two rows sharing a group, so "edit" cannot be a plain UPDATE:
-- the amount and both accounts have to move on both legs together. The client
-- used to do that as a DELETE followed by a separate create -- two requests
-- with nothing tying them together. When the second one failed (a dropped
-- connection, an expired session) the original pair was already gone, and the
-- error toast offered a retry of something that no longer existed.
--
-- One function, one transaction: the old row or pair is removed and the new
-- row or pair written, and neither happens without the other.
--
-- Deliberately not used for the ordinary case -- an expense or income row that
-- stays one. That is a real UPDATE, in place, keeping its id and created_at.
-- ============================================================================

create function public.replace_transaction(
    p_id            uuid,
    p_type          text,                 -- 'expense', 'income' or 'transfer'
    p_occurred_on   date,
    p_amount_cents  bigint,
    p_occurred_at   time    default '00:00:00',
    p_description   text    default null,
    p_category      text    default 'Uncategorized',
    p_account_id    uuid    default null, -- the account, or a transfer's From
    p_to_account    uuid    default null  -- a transfer's To; ignored otherwise
)
returns setof public.transactions
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_group uuid;
    v_found boolean;
begin
    if p_type not in ('expense', 'income', 'transfer') then
        raise exception 'Transaction type must be expense, income or transfer'
            using errcode = 'check_violation';
    end if;

    -- RLS scopes this to the caller's own rows, so somebody else's id simply
    -- does not exist from here.
    select true, transfer_group_id into v_found, v_group
      from public.transactions
     where id = p_id;

    if v_found is null then
        raise exception 'That transaction no longer exists.'
            using errcode = 'no_data_found';
    end if;

    -- Both legs of a transfer go together, whichever one was tapped.
    if v_group is not null then
        delete from public.transactions where transfer_group_id = v_group;
    else
        delete from public.transactions where id = p_id;
    end if;

    if p_type = 'transfer' then
        -- create_transfer validates the amount and that From and To differ,
        -- and raises inside this same transaction, so a rejected edit leaves
        -- the original pair exactly where it was.
        return query
            select * from public.create_transfer(
                p_account_id, p_to_account, p_amount_cents,
                p_occurred_on, p_occurred_at, p_description);
        return;
    end if;

    return query
    insert into public.transactions
        (user_id, occurred_on, occurred_at, description, amount_cents,
         category, account_id, type)
    values
        ((select auth.uid()), p_occurred_on, p_occurred_at,
         btrim(coalesce(p_description, '')), p_amount_cents,
         coalesce(nullif(btrim(p_category), ''), 'Uncategorized'),
         p_account_id, p_type)
    returning *;
end;
$$;
