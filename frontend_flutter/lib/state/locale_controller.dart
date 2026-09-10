import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language preference, persisted the same way [ThemeController] persists
/// light/dark.
///
/// A null [locale] means "follow the phone", which is what a first launch
/// gets: someone whose phone is already in Chinese should not have to find
/// the setting. Picking a language pins it, so an English phone can still run
/// Scandy in Chinese.
class LocaleController extends ChangeNotifier {
  static const _key = 'scandy.locale';

  /// The languages Scandy is actually translated into. `MaterialApp` gets this
  /// list too, so adding a third language means adding one entry here and one
  /// .arb file.
  static const supported = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  Locale? _locale;

  /// Null while following the system.
  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      _locale = Locale(saved);
    }
    notifyListeners();
  }

  /// Pass null to go back to following the phone.
  Future<void> set(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}
