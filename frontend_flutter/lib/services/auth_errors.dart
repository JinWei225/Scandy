/// Turns Supabase's auth errors into something worth showing a person.
///
/// The raw messages are written for developers -- "Invalid login credentials",
/// "User already registered", "For security purposes, you can only request
/// this after 51 seconds" -- and some of them are actively unhelpful to
/// somebody who just mistyped a password. This is the one place that
/// translation happens, so the wording stays consistent across all four
/// screens.
///
/// It matches on the *English* text Supabase sends, which is not localised and
/// does not change with the app's language, and answers in the reader's -- so
/// every caller passes its [L].
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';

String friendlyAuthError(L l, Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      // Deliberately does not say which half was wrong: that difference tells
      // an attacker whether an email has an account here.
      return l.authInvalidCredentials;
    }
    if (message.contains('email not confirmed')) {
      return l.authEmailNotConfirmed;
    }
    // Raised by the signup allowlist trigger, and already written for a
    // person -- but it says what happened without saying what to do.
    if (message.contains('invite only')) {
      return l.authInviteOnly;
    }

    // The same refusal, as the hosted service reports it. Supabase's own
    // GoTrue does not pass a trigger's message through -- it answers
    // {"code":"unexpected_failure","message":"Database error saving new user"}
    // whatever the database actually said, which is how a person ended up
    // being shown a JSON body.
    //
    // The wording stays honest about the uncertainty: this is *almost* always
    // the allowlist, but a genuine fault in the signup trigger would look
    // identical from here, so it says the account could not be created and
    // then gives the likely reason.
    if (message.contains('database error saving new user')) {
      return l.authCouldNotCreate;
    }

    // GoTrue rejects addresses whose domain it does not believe in, which
    // includes the reserved test TLDs.
    if (message.contains('email address') && message.contains('invalid')) {
      return l.authEmailRejected;
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return l.authAlreadyRegistered;
    }
    if (message.contains('password should be at least')) {
      return l.authPasswordTooShort;
    }
    if (message.contains('weak password') || message.contains('pwned')) {
      return l.authWeakPassword;
    }
    if (message.contains('unable to validate email') ||
        message.contains('invalid email')) {
      return l.authNotAnEmail;
    }
    if (message.contains('for security purposes') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return l.authTooManyAttempts;
    }
    if (message.contains('same password')) {
      return l.authSamePassword;
    }
    if (message.contains('expired') || message.contains('invalid token')) {
      return l.authLinkExpired;
    }
    // Last resort. Never the raw message if it is a response body -- an
    // unmapped failure showed a person
    // {"code":"unexpected_failure","message":"Database error saving new user"}
    // in a red box, which is worse than saying nothing useful.
    //
    // An unmapped message that *is* a sentence still comes through in English.
    // That is the honest trade: a wrong guess at what it means would be worse
    // than a sentence the reader has to translate.
    return _looksLikeAPayload(error.message)
        ? l.authGenericFailure
        : error.message;
  }

  // Offline, DNS failure, a project that is paused: all the same to the user.
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('TimeoutException')) {
    return l.authOffline;
  }
  return l.authGenericFailure;
}

/// True for anything that reads as a response body rather than a sentence.
bool _looksLikeAPayload(String message) {
  final text = message.trim();
  return text.startsWith('{') ||
      text.startsWith('[') ||
      text.contains('"code"') ||
      text.contains('"message"');
}

/// Client-side password rule, matching what Supabase is configured to enforce.
/// Checking here too means the person is told before a round trip.
String? passwordProblem(L l, String password) {
  if (password.length < 8) return l.passwordUseAtLeast8;
  return null;
}

String? emailProblem(L l, String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return l.enterYourEmail;
  // Deliberately loose. The server does the real check, and an over-strict
  // pattern here would reject valid addresses for no benefit.
  if (!trimmed.contains('@') || !trimmed.contains('.')) {
    return l.authNotAnEmail;
  }
  return null;
}
