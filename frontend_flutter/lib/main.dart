import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/api_client.dart';
import 'services/share_intent_service.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  await api.loadBaseUrl();

  final theme = ThemeController();
  await theme.load();

  final shareIntent = ShareIntentService();
  await shareIntent.start();

  runApp(ScandyApp(api: api, theme: theme, shareIntent: shareIntent));
}

class ScandyApp extends StatelessWidget {
  const ScandyApp({
    super.key,
    required this.api,
    required this.theme,
    required this.shareIntent,
  });

  final ApiClient api;
  final ThemeController theme;
  final ShareIntentService shareIntent;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider(create: (_) => AppState(api)..loadAll()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Scandy',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: buildScandyTheme(Brightness.light),
          darkTheme: buildScandyTheme(Brightness.dark),
          routes: {
            '/settings': (_) => const Scaffold(
                  body: SafeArea(child: SettingsScreen(embedded: false)),
                ),
          },
          builder: (context, child) => _SystemBars(child: child!),
          home: AppShell(shareIntent: shareIntent),
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
