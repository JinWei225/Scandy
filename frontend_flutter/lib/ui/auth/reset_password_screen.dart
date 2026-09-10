import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_errors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/widgets.dart';
import 'auth_scaffold.dart';

/// Shown when the app is opened by a password-reset link.
///
/// By this point Supabase has already exchanged the link for a *recovery*
/// session, so technically the person is signed in -- which is why AuthGate
/// intercepts the passwordRecovery event and shows this instead of the app.
/// Letting them straight in would leave the reset half-finished, still holding
/// the password they could not remember.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});

  /// Called once the password has actually been changed, so AuthGate can drop
  /// the recovery flag and hand over to the app.
  final VoidCallback onDone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final issue = passwordProblem(_password.text);
    final mismatch =
        _password.text != _confirm.text ? 'Both passwords must match.' : null;
    setState(() {
      _passwordError = issue;
      _confirmError = mismatch;
      _error = null;
    });
    if (issue != null || mismatch != null) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    // Sign out rather than just dismissing: the recovery session is a way in,
    // and leaving it live on a device where somebody abandoned the reset is
    // the one thing this screen exists to prevent.
    await Supabase.instance.client.auth.signOut();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Then you will be signed in.',
      children: [
        PasswordField(
          label: 'New password',
          controller: _password,
          hint: 'At least 8 characters',
          autofocus: true,
          errorText: _passwordError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        PasswordField(
          label: 'Confirm password',
          controller: _confirm,
          errorText: _confirmError,
          onSubmitted: _busy ? null : _save,
        ),
        const SizedBox(height: 20),
        AuthError(_error),
        PrimaryButton(label: 'Save password', busy: _busy, onPressed: _save),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: Text('Cancel',
              style: ScandyText.link.copyWith(color: c.textSecondary)),
        ),
      ],
    );
  }
}
