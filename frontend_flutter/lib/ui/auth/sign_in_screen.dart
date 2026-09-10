import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_errors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import 'auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l = context.l;
    final emailIssue = emailProblem(l, _email.text);
    setState(() {
      _emailError = emailIssue;
      _passwordError = _password.text.isEmpty ? l.enterYourPassword : null;
      _error = null;
    });
    if (emailIssue != null || _password.text.isEmpty) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // No navigation here on purpose: AuthGate is listening to the auth state
      // and swaps the whole app over. Pushing a route as well would leave the
      // sign-in screen underneath the app in the back stack.
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
    return AuthScaffold(
      title: l.signInTitle,
      subtitle: l.signInSubtitle,
      children: [
        ScandyField(
          label: l.fieldEmail,
          controller: _email,
          hint: l.hintEmail,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        const SizedBox(height: 16),
        PasswordField(
          label: l.fieldPassword,
          controller: _password,
          errorText: _passwordError,
          onSubmitted: _busy ? null : _signIn,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ForgotPasswordScreen(initialEmail: _email.text.trim()),
                    )),
            child: Text(l.forgotPassword,
                style: ScandyText.link.copyWith(color: c.accent)),
          ),
        ),
        const SizedBox(height: 12),
        AuthError(_error),
        PrimaryButton(label: l.signIn, busy: _busy, onPressed: _signIn),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l.newHere,
                style: ScandyText.sheetItemSubtitle
                    .copyWith(color: c.textSecondary)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SignUpScreen(),
                      )),
              child: Text(l.createAnAccount,
                  style: ScandyText.link.copyWith(color: c.accent)),
            ),
          ],
        ),
      ],
    );
  }
}
