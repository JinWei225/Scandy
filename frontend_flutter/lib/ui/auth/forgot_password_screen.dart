import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_errors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import 'auth_scaffold.dart';

/// Where the password-reset email should send people back to.
///
/// On Android and iOS this is the custom scheme declared in
/// AndroidManifest.xml, which is why that intent-filter exists; on the web
/// there is a real origin, so null lets Supabase use the project's configured
/// Site URL. Either value must also be listed under
/// Authentication > URL Configuration > Redirect URLs in the dashboard --
/// Supabase silently drops a redirect that is not on that list, and the
/// symptom is a link that opens to a blank page.
String? get passwordResetRedirect =>
    kIsWeb ? null : 'com.jinwei.scandy://login-callback';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);

  bool _busy = false;
  bool _sent = false;
  String? _error;
  String? _emailError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l;
    final issue = emailProblem(l, _email.text);
    setState(() {
      _emailError = issue;
      _error = null;
    });
    if (issue != null) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _email.text.trim(),
        redirectTo: passwordResetRedirect,
      );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;

    if (_sent) {
      return AuthScaffold(
        title: l.checkYourEmail,
        // Deliberately does not confirm whether an account exists for this
        // address. Supabase answers the same way for both, and saying more
        // here would give that away.
        subtitle: l.resetSentSubtitle(_email.text.trim()),
        showBack: true,
        children: [
          Text(
            l.resetSentBody,
            style:
                ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: l.backToSignIn,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: l.resetTitle,
      subtitle: l.resetSubtitle,
      showBack: true,
      children: [
        ScandyField(
          label: l.fieldEmail,
          controller: _email,
          hint: l.hintEmail,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          errorText: _emailError,
        ),
        const SizedBox(height: 20),
        AuthError(_error),
        PrimaryButton(label: l.sendResetLink, busy: _busy, onPressed: _send),
      ],
    );
  }
}
