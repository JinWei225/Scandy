/// Where Supabase lives, supplied at build time.
///
/// Both values are baked in with --dart-define, the same way the old
/// SCANDY_SERVER_URL was:
///
///     flutter run \
///         --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///         --dart-define=SUPABASE_ANON_KEY=<anon key>
///
/// SUPABASE_ANON_KEY takes either form of the public key -- the legacy anon
/// JWT or a newer sb_publishable_... key. They are passed to the SDK the same
/// way and mean the same thing.
///
/// The anon key belongs in the client and is safe there. It identifies the
/// project and nothing else: every request it makes is still subject to row
/// level security, so it grants no more access than being signed out. The key
/// that *does* bypass RLS is the service_role key, which must never appear in
/// this directory -- it is for the one-off data migration and nothing else.
library;

abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Shown instead of the app when the build forgot the defines. Failing here
  /// with an explanation beats letting Supabase.initialize throw a stack trace
  /// nobody can act on.
  static const missingMessage =
      'This build has no Supabase credentials.\n\n'
      'Rebuild with:\n'
      '  --dart-define=SUPABASE_URL=https://<ref>.supabase.co\n'
      '  --dart-define=SUPABASE_ANON_KEY=<anon key>\n\n'
      'Both are in your project dashboard under Settings > API.';
}
