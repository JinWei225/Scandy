import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_errors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import 'auth_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _needsConfirmation = false;
  String? _error;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final emailIssue = emailProblem(_email.text);
    final passwordIssue = passwordProblem(_password.text);
    setState(() {
      _emailError = emailIssue;
      _passwordError = passwordIssue;
      _error = null;
    });
    if (emailIssue != null || passwordIssue != null) return;

    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        // Read by the handle_new_user() trigger to fill in profiles.display_name.
        data: {'display_name': _name.text.trim()},
      );

      // With email confirmation switched on, signUp returns a user but no
      // session -- nothing else will happen until they tap the link, so say so
      // rather than leaving them on a form that looks like it did nothing.
      if (response.session == null && mounted) {
        setState(() => _needsConfirmation = true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;

    if (_needsConfirmation) {
      return AuthScaffold(
        title: 'Check your email',
        subtitle:
            'We sent a confirmation link to ${_email.text.trim()}. Tap it, then '
            'come back and sign in.',
        showBack: true,
        children: [
          Text(
            'Nothing arrived? It can take a minute, and it sometimes lands in '
            'spam.',
            style:
                ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Back to sign in',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Create an account',
      subtitle: 'Your ledger is yours alone — nobody else can see it.',
      showBack: true,
      children: [
        ScandyField(
          label: 'Name',
          controller: _name,
          hint: 'What should we call you?',
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 16),
        ScandyField(
          label: 'Email',
          controller: _email,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        const SizedBox(height: 16),
        PasswordField(
          label: 'Password',
          controller: _password,
          hint: 'At least 8 characters',
          errorText: _passwordError,
          onSubmitted: _busy ? null : _signUp,
        ),
        const SizedBox(height: 20),
        AuthError(_error),
        PrimaryButton(label: 'Create account', busy: _busy, onPressed: _signUp),
      ],
    );
  }
}
