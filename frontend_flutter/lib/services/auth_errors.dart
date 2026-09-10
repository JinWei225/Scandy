/// Turns Supabase's auth errors into something worth showing a person.
///
/// The raw messages are written for developers -- "Invalid login credentials",
/// "User already registered", "For security purposes, you can only request
/// this after 51 seconds" -- and some of them are actively unhelpful to
/// somebody who just mistyped a password. This is the one place that
/// translation happens, so the wording stays consistent across all four
/// screens.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyAuthError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      // Deliberately does not say which half was wrong: that difference tells
      // an attacker whether an email has an account here.
      return 'That email and password do not match. Check both and try again.';
    }
    if (message.contains('email not confirmed')) {
      return 'Check your email and tap the confirmation link first.';
    }
    // Raised by the signup allowlist trigger, and already written for a
    // person -- but it says what happened without saying what to do.
    if (message.contains('invite only')) {
      return 'Scandy is invite only at the moment. Ask for your email address '
          'to be added, then try again.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'That email already has an account. Try signing in instead.';
    }
    if (message.contains('password should be at least')) {
      return 'That password is too short — use at least 8 characters.';
    }
    if (message.contains('weak password') || message.contains('pwned')) {
      return 'That password is too easy to guess. Try a longer one.';
    }
    if (message.contains('unable to validate email') ||
        message.contains('invalid email')) {
      return "That does not look like an email address.";
    }
    if (message.contains('for security purposes') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Too many attempts just now. Wait a minute and try again.';
    }
    if (message.contains('same password')) {
      return 'That is the password you already have. Choose a different one.';
    }
    if (message.contains('expired') || message.contains('invalid token')) {
      return 'That link has expired. Ask for a new one.';
    }
    return error.message;
  }

  // Offline, DNS failure, a project that is paused: all the same to the user.
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('TimeoutException')) {
    return 'Cannot reach Scandy right now. Check your connection.';
  }
  return 'Something went wrong. Try again.';
}

/// Client-side password rule, matching what Supabase is configured to enforce.
/// Checking here too means the person is told before a round trip.
String? passwordProblem(String password) {
  if (password.length < 8) return 'Use at least 8 characters.';
  return null;
}

String? emailProblem(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return 'Enter your email address.';
  // Deliberately loose. The server does the real check, and an over-strict
  // pattern here would reject valid addresses for no benefit.
  if (!trimmed.contains('@') || !trimmed.contains('.')) {
    return 'That does not look like an email address.';
  }
  return null;
}
