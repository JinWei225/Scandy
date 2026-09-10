import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/share_intent_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../shell/app_shell.dart';
import 'reset_password_screen.dart';
import 'sign_in_screen.dart';

/// Decides whether you get the app or the sign-in screen.
///
/// Everything below this widget can assume there is a signed-in user. The
/// decision is driven by onAuthStateChange rather than by a one-off read, so a
/// session that is restored from disk at launch, a token that expires while
/// the app is open, and a sign-out from Settings all land in the same place.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.shareIntent});

  final ShareIntentService shareIntent;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;

  Session? _session;

  /// True between a password-reset link opening the app and the new password
  /// being saved. Supabase has already granted a real session by then, so
  /// without this flag the app would simply open and the reset would never
  /// finish.
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;

    _sub = auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      switch (data.event) {
        case AuthChangeEvent.passwordRecovery:
          // A reset link arriving while "Check your email" is still on screen
          // leaves that screen on top of the one asking for the new password.
          // It looked like the reset had failed and offered "Back to sign in",
          // which then popped through to the real screen underneath.
          _clearPushedRoutes();
          setState(() {
            _session = data.session;
            _recovering = true;
          });
          return;

        case AuthChangeEvent.signedOut:
          // Settings is pushed as a route, so signing out from it swapped this
          // widget for the sign-in screen *underneath* a Settings page that
          // stayed put. It read as a sign-out button that did nothing.
          _clearPushedRoutes();
          // Drop the previous person's transactions from memory. Without this
          // the next sign-in shows the last user's ledger until the first load
          // finishes -- brief, but it is exactly the thing separate ledgers
          // are meant to prevent.
          context.read<AppState>().clear();
          setState(() {
            _session = null;
            _recovering = false;
          });
          return;

        case AuthChangeEvent.signedIn:
          _clearPushedRoutes();
          setState(() => _session = data.session);
          return;

        default:
          setState(() => _session = data.session);
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  /// Drop anything pushed on top of this gate.
  ///
  /// Screens above it -- Settings, Sign up, Forgot password -- live in the same
  /// Navigator, so swapping this widget's child does not remove them. Whatever
  /// was on top simply stays there, hiding the screen the person should now be
  /// looking at. Every auth transition needs this, not just signing in.
  void _clearPushedRoutes() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.popUntil((r) => r.isFirst);
  }

  void _finishRecovery() {
    if (!mounted) return;
    setState(() {
      _recovering = false;
      _session = Supabase.instance.client.auth.currentSession;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering) {
      return ResetPasswordScreen(onDone: _finishRecovery);
    }
    if (_session == null) {
      return const SignInScreen();
    }
    return _SignedIn(
      // Keyed by user so that switching account rebuilds the whole subtree
      // rather than reusing widgets holding the previous person's data.
      key: ValueKey(_session!.user.id),
      shareIntent: widget.shareIntent,
    );
  }
}

/// The app itself, plus the first data load for whoever just signed in.
class _SignedIn extends StatefulWidget {
  const _SignedIn({super.key, required this.shareIntent});

  final ShareIntentService shareIntent;

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  @override
  void initState() {
    super.initState();
    // After the first frame: loadAll() notifies listeners, and doing that
    // during a build is an error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) =>
      AppShell(shareIntent: widget.shareIntent);
}

/// Shown in place of everything when the build has no Supabase credentials.
/// A stack trace from Supabase.initialize would be less useful.
class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.settings_outlined, size: 32, color: c.iconMuted),
                  const SizedBox(height: 14),
                  Text(context.l.notConfiguredTitle,
                      style: ScandyText.sectionTitle
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: ScandyText.sheetItemSubtitle
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
