import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the bundled Plus Jakarta Sans faces before any test runs.
///
/// `flutter test` does not load fonts declared in pubspec.yaml — every glyph
/// falls back to the placeholder test font, which draws solid blocks. Layout
/// still verifies, but typography does not, and golden files end up unable to
/// catch a wrong weight, size or letter-spacing. Loading the real faces here
/// makes the goldens show what the app actually renders.
///
/// Flutter picks this file up automatically for the whole `test/` tree.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weights = [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ];

  // The family name must match the one declared in pubspec.yaml, otherwise
  // `fontFamily: 'PlusJakartaSans'` still resolves to the fallback.
  final loader = FontLoader('PlusJakartaSans');
  for (final weight in weights) {
    loader.addFont(
      rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'),
    );
  }
  await loader.load();

  // Material Icons ships with `uses-material-design: true` but is no more
  // registered than our own family, so every glyph in the nav and the row
  // tiles would otherwise render as a placeholder box.
  try {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  } catch (_) {
    // Asset key varies between Flutter versions; icons falling back to boxes
    // is cosmetic and must never fail the suite.
  }

  await testMain();
}
