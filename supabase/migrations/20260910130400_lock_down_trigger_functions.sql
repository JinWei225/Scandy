-- ============================================================================
-- Take EXECUTE away from the trigger functions.
--
-- Supabase's Security Advisor flags handle_new_user() twice: "Public Can
-- Execute SECURITY DEFINER Function" and "Signed-In Users Can Execute
-- SECURITY DEFINER Function". Both are correct. Postgres grants EXECUTE on new
-- functions in `public` to PUBLIC by default, and Supabase additionally grants
-- to anon and authenticated -- so a signed-in user could call a function that
-- runs with the *definer's* privileges and deliberately bypasses RLS.
--
-- In practice handle_new_user() is hard to abuse: it `returns trigger`, and
-- Postgres refuses to call a trigger function outside a trigger context. That
-- is an argument for the warning being low severity, not for leaving a
-- privilege granted that nothing needs.
--
-- Revoking EXECUTE does not stop the triggers. The trigger mechanism invokes
-- these functions itself and never checks the current user's EXECUTE privilege
-- -- which the signup test in tests/rls_isolation_test.sql proves, since it
-- asserts that inserting into auth.users still seeds a profile and 14
-- categories.
--
-- The three RPCs are deliberately untouched: create_transfer,
-- rename_category and record_due_subscriptions exist to be called by the app,
-- run as SECURITY INVOKER, and are confined by RLS like any other statement.
-- ============================================================================

revoke execute on function public.handle_new_user()
    from public, anon, authenticated;

revoke execute on function public.forbid_deleting_last_category()
    from public, anon, authenticated;
