import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/language_toggle.dart';

/// The frame every auth screen sits in.
///
/// Centred and width-capped rather than full-bleed: these screens are three
/// fields and a button, and on a desktop browser -- which is how the web build
/// is used -- a form stretched across 1400px reads as broken.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        if (showBack)
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(Icons.arrow_back,
                                size: 22, color: c.textPrimary),
                            tooltip: context.l.actionBack,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 44, minHeight: 44),
                            alignment: Alignment.centerLeft,
                          ),
                        const Spacer(),
                        const LanguageToggle(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: ScandyText.greeting.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: ScandyText.sheetItemSubtitle
                        .copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: 26),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A password field with a reveal toggle.
///
/// Not reusing ScandyField: that one has no obscureText, and typing a password
/// blind on a phone keyboard is the single biggest cause of "it says my
/// password is wrong".
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.hint,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final String? hint;
  final bool autofocus;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: ScandyText.statLabel.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _hidden,
          autofocus: widget.autofocus,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: widget.textInputAction,
          onSubmitted: (_) => widget.onSubmitted?.call(),
          style: ScandyText.rowTitleLarge.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: ScandyText.rowTitleLarge.copyWith(color: c.iconMuted),
            errorText: widget.errorText,
            filled: true,
            fillColor: c.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide(color: c.accent, width: 1.6),
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: c.iconMuted,
              ),
              tooltip: _hidden
                  ? context.l.showPassword
                  : context.l.hidePassword,
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline error above the submit button. A SnackBar is wrong here: it vanishes
/// while you are still reading it, and on the web build it can land off-screen
/// entirely.
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.negativeSoft,
          borderRadius: BorderRadius.circular(ScandyRadius.tile),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: c.negative),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message!,
                style: ScandyText.sheetItemSubtitle.copyWith(color: c.negative),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
