# Scandy on Supabase

The database is the source of truth and the security boundary. There is no
application server: the Flutter app talks to Supabase directly, and the only
thing standing between your ledger and your mum's is row level security. That
is why `tests/` exists and why it should stay green.

## Layout

    migrations/
      20260910130000_schema.sql              tables, constraints, indexes
      20260910130100_rls.sql                 policies + the last-category guard
      20260910130200_balances_and_rpcs.sql   the view and the three functions
      20260910130300_new_user.sql            what happens at signup
      20260910130400_lock_down_...            revoke EXECUTE on trigger functions
      20260910130500_allow_user_deletion.sql  let an account actually be deleted
    tests/
      rls_isolation_test.sql                 two users cannot reach each other
      subscriptions_test.sql                 the month arithmetic, pinned dates

## First-time setup

    supabase init          # if supabase/config.toml does not exist yet
    supabase link --project-ref <your-project-ref>
    supabase db push       # apply migrations to the hosted project

Locally, `supabase db reset` rebuilds from the migrations every time, which is
the only way to be sure the migrations -- not your dashboard clicking -- are the
real schema.

## Running the tests

    supabase start          # once; `supabase stop` when you are done
    ./supabase/tests/run.sh

The runner goes through `docker exec` into the stack's own database container
rather than psql, because the Supabase CLI ships no psql client and there is no
reason to install Postgres locally just for this.

Each file runs inside a transaction that rolls back, so they leave no rows
behind and can be run repeatedly against the same database. A failed assertion
raises, `ON_ERROR_STOP=1` turns that into a non-zero exit code, and the runner
propagates it -- so this works unchanged as a CI gate.

After changing a migration, `supabase db reset` rebuilds from the migration
files and re-runs them in order. That is the only way to be sure the migrations
are the real schema, rather than something you clicked into the dashboard.

## Things that will bite you if you change them

**`security_invoker = true` on `account_balances`.** A Postgres view normally
evaluates the underlying tables' RLS as its *owner*, which here is a superuser.
Drop that flag and the view serves every user everybody's balances, no matter
how correct the table policies are. The isolation test asserts this specific
case.

**`with check` on every policy, not just `using`.** `using` filters what you can
read; `with check` validates what you write. A policy with only `using` lets a
signed-in user INSERT rows stamped with someone else's `user_id` -- they could
not read them back, but they would have written into another person's ledger.

**`(select auth.uid())` rather than a bare `auth.uid()`.** The subselect is
evaluated once per statement instead of once per row. On `transactions` that is
the difference between an index scan and a sequential scan.

**`set search_path = ''` on every function.** This is why every name inside them
is schema qualified. Without it, anything able to create objects could shadow an
unqualified name and change what these functions resolve to.

**The deep-link redirect must be allow-listed.** `com.jinwei.scandy://login-callback`
has to appear in `additional_redirect_urls` here *and* under
Authentication > URL Configuration > Redirect URLs in the hosted project. If it
does not, Supabase silently swaps it for the Site URL and the reset link opens
a browser tab that cannot finish the reset -- no error anywhere. The exact
string is enough; no wildcard is needed. (Note that `redirect_to` travels as a
query parameter, not in the request body -- worth knowing if you ever test this
with curl.)

**Deleting a user is a cascade, and triggers fire during it.** This is why
`forbid_deleting_last_category()` checks whether the owner still exists before
enforcing its rule: without that check, removing an account failed with
"Cannot delete the last expense category", naming something the caller never
asked about. Any future trigger on a table keyed to `user_id` has the same
trap waiting.

## What is deliberately *not* here

Adding and deleting a category are plain inserts and deletes through RLS -- the
validations that used to live in `_validate_category_name()` are table
constraints now, and "you cannot delete your last category" is a trigger. Only
renaming needs a function, because it has to reach the category, the
transaction history and any subscription in one go.
