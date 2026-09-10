-- ============================================================================
-- Scandy: one private ledger per user.
--
-- Separation is enforced by row level security (next migration), never by the
-- client. Every table below carries user_id for exactly that reason.
--
-- Two deliberate departures from the SQLite schema this replaces:
--
--   Money is `bigint` cents. The old schema kept cents in a TEXT column and
--   every balance did SUM(CAST(amount AS INTEGER)), where a malformed row cast
--   silently to zero. A bigint with a check constraint fails loudly at write
--   time instead of quietly changing a balance.
--
--   Dates and times stay in separate `date` and `time` columns rather than one
--   timestamptz. Every figure in this app is a naive local wall clock reading
--   -- "what did I spend in September" -- and a timestamptz would shift
--   transactions across month boundaries whenever the session timezone
--   differed from the one the receipt was written in.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user, created by the trigger in 20260910130300.
-- ---------------------------------------------------------------------------
create table public.profiles (
    id           uuid primary key references auth.users on delete cascade,
    display_name text,
    -- Both users are in Malaysia and the app hardcodes RM today. The column
    -- exists so that adding a second currency is a feature, not a migration.
    currency     text not null default 'RM',
    created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- accounts
-- ---------------------------------------------------------------------------
create table public.accounts (
    id                    uuid primary key default gen_random_uuid(),
    user_id               uuid not null references auth.users on delete cascade,
    name                  text not null,
    -- The closed set offered by `accountTypes` in account_form_sheet.dart, and
    -- the only four values present in the data being migrated.
    type                  text not null
                          check (type in ('Bank', 'Card', 'E-Wallet', 'Cash')),
    initial_balance_cents bigint not null default 0,
    created_at            timestamptz not null default now(),

    constraint accounts_name_not_blank check (btrim(name) <> '')
);
create index accounts_user_id_idx on public.accounts (user_id);

-- ---------------------------------------------------------------------------
-- categories
--
-- 'transfer' is not a kind here. The old JSON store carried a third bucket
-- that was force-overwritten to exactly ["Transfer"] on every read, so it was
-- never user data; create_transfer() writes that literal instead.
-- ---------------------------------------------------------------------------
create table public.categories (
    id      uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users on delete cascade,
    kind    text not null check (kind in ('expense', 'income')),
    name    text not null,

    -- The validations that used to live in _validate_category_name(), moved
    -- into the database so no client can route around them.
    constraint categories_name_not_blank check (btrim(name) <> ''),
    constraint categories_name_length    check (char_length(name) <= 40),
    constraint categories_name_reserved  check (lower(btrim(name)) <> 'transfer')
);

-- Case-insensitive, matching the old check of `name.lower() in (c.lower() ...)`.
create unique index categories_user_kind_name_idx
    on public.categories (user_id, kind, lower(btrim(name)));

-- ---------------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------------
create table public.transactions (
    id                uuid primary key default gen_random_uuid(),
    user_id           uuid not null references auth.users on delete cascade,
    occurred_on       date not null,
    occurred_at       time not null default '00:00:00',
    description       text not null default '',
    -- Always positive; `type` carries the sign. The old code stored the same
    -- way, so this constraint documents an invariant rather than adding one.
    amount_cents      bigint not null check (amount_cents >= 0),
    -- Free text, not a foreign key: renaming cascades through rename_category()
    -- and deleting a category deliberately leaves history alone, both of which
    -- a FK would prevent.
    category          text not null default 'Uncategorized',
    account_id        uuid references public.accounts on delete set null,
    type              text not null check (type in ('expense', 'income')),
    -- Both legs of a transfer share one value. Replaces the old pair of
    -- '<uuid>_out' / '<uuid>_in' string ids, which cannot survive uuid keys.
    transfer_group_id uuid,
    created_at        timestamptz not null default now()
);

-- The transaction list is always "this user, newest first".
create index transactions_user_date_idx
    on public.transactions (user_id, occurred_on desc, occurred_at desc);

-- Per-account counts and balances.
create index transactions_account_idx
    on public.transactions (account_id);

-- Partial: only transfer legs carry a group, and they are a small minority.
create index transactions_transfer_group_idx
    on public.transactions (transfer_group_id)
    where transfer_group_id is not null;

-- ---------------------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------------------
create table public.subscriptions (
    id                 uuid primary key default gen_random_uuid(),
    user_id            uuid not null references auth.users on delete cascade,
    name               text not null,
    amount_cents       bigint not null check (amount_cents > 0),
    category           text not null default 'Bills & Utilities',
    account_id         uuid references public.accounts on delete set null,
    day_of_month       int not null check (day_of_month between 1 and 31),
    -- The due date of the month most recently recorded -- not "when we last
    -- looked". record_due_subscriptions() works out what is owed from this.
    last_recorded_date date,
    created_at         timestamptz not null default now(),

    constraint subscriptions_name_not_blank check (btrim(name) <> '')
);
create index subscriptions_user_id_idx on public.subscriptions (user_id);
