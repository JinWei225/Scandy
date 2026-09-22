-- tools/migrate_to_supabase.py inserted every account from the old JSON store
-- in one batch, relying on created_at's `default now()` instead of carrying
-- over the old store's per-account timestamps. That left the whole batch
-- sharing one created_at, so their relative order was undefined -- combined
-- with fetchAccounts() sorting the wrong direction, this is why new accounts
-- were appearing above old ones and existing accounts reshuffled on their
-- own. This restores the original creation order from the old store's
-- ISO-timestamp ids (accounts without one, e.g. "Cash", were the most
-- recently added before migration and keep their migration-batch timestamp,
-- which already sorts after these).
update public.accounts a
set created_at = v.created_at
from (
    values
        ('PBE',              timestamptz '2026-01-24T16:04:49.305654Z'),
        ('TNG E-wallet',     timestamptz '2026-01-24T16:05:23.642518Z'),
        ('Cat TNG Card',     timestamptz '2026-01-24T16:06:00.915080Z'),
        ('IC Card',          timestamptz '2026-01-24T16:06:20.931563Z'),
        ('Merdeka TNG Card', timestamptz '2026-01-24T16:06:44.067552Z'),
        ('Student Card',     timestamptz '2026-01-24T16:08:48.729694Z'),
        ('UOB',              timestamptz '2026-01-24T16:10:04.362034Z'),
        ('MAE',              timestamptz '2026-01-24T16:10:32.510042Z'),
        ('ShopeePay',        timestamptz '2026-02-20T16:18:09.111297Z'),
        ('Cleanproplus',     timestamptz '2026-02-24T19:17:40.855632Z'),
        ('GrabPay',          timestamptz '2026-02-28T13:41:00.614046Z')
) as v(name, created_at)
where a.name = v.name
  and a.user_id = (select id from auth.users where email = 'nefflymicn@gmail.com');
