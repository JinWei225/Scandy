import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/locale_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// The one-tap language switch that sits on the auth screens.
///
/// Settings has the full three-way control, but Settings is behind a password:
/// somebody who cannot read English has to be able to switch *before* they
/// sign up, and the label is deliberately written in the language it switches
/// to, so it reads as an offer rather than a state.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final controller = context.watch<LocaleController>();

    // The *resolved* locale, not the controller's — while it is following the
    // phone, the controller holds null and only Localizations knows which
    // language actually came out of that.
    final isChinese =
        Localizations.localeOf(context).languageCode.startsWith('zh');
    final target = isChinese ? const Locale('en') : const Locale('zh');
    final label = isChinese ? 'English' : '中文';

    return Material(
      color: c.surfaceMuted,
      borderRadius: BorderRadius.circular(ScandyRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.set(target),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 16, color: c.textTertiary),
              const SizedBox(width: 7),
              Text(
                label,
                style: ScandyText.link.copyWith(color: c.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
