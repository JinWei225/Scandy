import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark preference, persisted. The design ships both themes, so the
/// default follows the system and the user can pin either.
class ThemeController extends ChangeNotifier {
  static const _key = 'scandy.themeMode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = switch (prefs.getString(_key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> set(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
