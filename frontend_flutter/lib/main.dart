import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/l10n.dart';
import 'services/scandy_repository.dart';
import 'services/share_intent_service.dart';
import 'services/supabase_config.dart';
import 'state/app_state.dart';
import 'state/locale_controller.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/auth/auth_gate.dart';
import 'ui/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything reads Supabase.instance. This also restores a saved
  // session from disk, which is why the app opens straight to the ledger
  // rather than asking for a password every launch.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // publishableKey, not the deprecated anonKey: the SDK collapses both to
      // the same value, so a legacy anon JWT works here unchanged.
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // Month and weekday names for every locale intl ships. GlobalMaterial-
  // Localizations loads them for the *active* locale on its own, but a
  // DateFormat built before that finishes throws, and the greeting date is
  // formatted in the first frame.
  await initializeDateFormatting();

  final theme = ThemeController();
  await theme.load();

  final locale = LocaleController();
  await locale.load();

  final shareIntent = ShareIntentService();
  await shareIntent.start();

  runApp(ScandyApp(theme: theme, locale: locale, shareIntent: shareIntent));
}

class ScandyApp extends StatelessWidget {
  const ScandyApp({
    super.key,
    required this.theme,
    required this.locale,
    required this.shareIntent,
  });

  final ThemeController theme;
  final LocaleController locale;
  final ShareIntentService shareIntent;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: locale),
        ChangeNotifierProvider(create: (_) => AppState(SupabaseRepository())),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, theme, locale, _) => MaterialApp(
          title: 'Scandy',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          // Null means follow the phone, which is what a first launch gets.
          locale: locale.locale,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: LocaleController.supported,
          theme: buildScandyTheme(Brightness.light),
          darkTheme: buildScandyTheme(Brightness.dark),
          routes: {
            '/settings': (_) => const Scaffold(
                  body: SafeArea(child: SettingsScreen(embedded: false)),
                ),
          },
          builder: (context, child) => _SystemBars(child: child!),
          home: SupabaseConfig.isConfigured
              ? AuthGate(shareIntent: shareIntent)
              : const MissingConfigScreen(
                  message: SupabaseConfig.missingMessage),
        ),
      ),
    );
  }
}

/// Paints the status and gesture bars to match the design's frames instead of
/// leaving Android's defaults over a warm background.
class _SystemBars extends StatelessWidget {
  const _SystemBars({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: c.surface,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
