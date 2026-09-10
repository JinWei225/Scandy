import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n.dart';
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
    final l = context.l;
    final emailIssue = emailProblem(l, _email.text);
    final passwordIssue = passwordProblem(l, _password.text);
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
        // Read by the handle_new_user() trigger: the name fills in
        // profiles.display_name, and the language decides which set of
        // starter categories the account gets. Sent once, at sign-up --
        // changing the app's language later renames nothing, because by then
        // the categories are the person's own rows.
        data: {
          'display_name': _name.text.trim(),
          'locale': Localizations.localeOf(context).languageCode,
        },
      );

      // With email confirmation switched on, signUp returns a user but no
      // session -- nothing else will happen until they tap the link, so say so
      // rather than leaving them on a form that looks like it did nothing.
      if (response.session == null && mounted) {
        setState(() => _needsConfirmation = true);
      }
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

    if (_needsConfirmation) {
      return AuthScaffold(
        title: l.checkYourEmail,
        subtitle: l.confirmSentTo(_email.text.trim()),
        showBack: true,
        children: [
          Text(
            l.confirmNothingArrived,
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
      title: l.createAnAccount,
      subtitle: l.signUpSubtitle,
      showBack: true,
      children: [
        ScandyField(
          label: l.fieldName,
          controller: _name,
          hint: l.hintYourName,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 16),
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
          hint: l.hintAtLeast8,
          errorText: _passwordError,
          onSubmitted: _busy ? null : _signUp,
        ),
        const SizedBox(height: 20),
        AuthError(_error),
        PrimaryButton(label: l.createAccount, busy: _busy, onPressed: _signUp),
      ],
    );
  }
}
