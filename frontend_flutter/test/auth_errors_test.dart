// friendlyAuthError is the only thing between Supabase's developer-facing
// messages and a red box on the sign-in screen. It matches on English text the
// server sends, so a reworded server message silently falls through to the
// raw text -- these pin every mapping it knows.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/l10n/l10n.dart';
import 'package:scandy/services/auth_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late L l;
  setUpAll(() async => l = await L.delegate.load(const Locale('en')));

  group('friendlyAuthError', () {
    // What Supabase actually says, and which sentence it should become.
    final cases = <String, String Function(L)>{
      'Invalid login credentials': (l) => l.authInvalidCredentials,
      'Email not confirmed': (l) => l.authEmailNotConfirmed,
      'Scandy is invite only': (l) => l.authInviteOnly,
      'Database error saving new user': (l) => l.authCouldNotCreate,
      'Email address "a@b.invalid" is invalid': (l) => l.authEmailRejected,
      'User already registered': (l) => l.authAlreadyRegistered,
      'A user with this email address has already been registered': (l) =>
          l.authAlreadyRegistered,
      'Password should be at least 8 characters.': (l) =>
          l.authPasswordTooShort,
      'Weak password': (l) => l.authWeakPassword,
      'Password is known to be weak and easy to guess (pwned)': (l) =>
          l.authWeakPassword,
      'Unable to validate email address: invalid format': (l) =>
          l.authNotAnEmail,
      'For security purposes, you can only request this after 51 seconds.': (
        l,
      ) => l.authTooManyAttempts,
      'Email rate limit exceeded': (l) => l.authTooManyAttempts,
      'Too many requests': (l) => l.authTooManyAttempts,
      'New password should be different from the old password (same password)':
          (l) => l.authSamePassword,
      'Email link is invalid or has expired': (l) => l.authLinkExpired,
      'Invalid token': (l) => l.authLinkExpired,
    };

    cases.forEach((server, expected) {
      test(server, () {
        expect(friendlyAuthError(l, AuthException(server)), expected(l));
      });
    });

    test('matching ignores case', () {
      expect(
        friendlyAuthError(l, AuthException('INVALID LOGIN CREDENTIALS')),
        l.authInvalidCredentials,
      );
    });

    test('an unmapped sentence is passed through as written', () {
      const sentence = 'Signups not allowed for this instance';
      expect(friendlyAuthError(l, AuthException(sentence)), sentence);
    });

    test('an unmapped response body is never shown', () {
      for (final body in [
        '{"code":"unexpected_failure","message":"boom"}',
        '[1,2]',
        'error: "code" 500',
      ]) {
        expect(
          friendlyAuthError(l, AuthException(body)),
          l.authGenericFailure,
          reason: body,
        );
      }
    });

    test('network failures read as offline', () {
      for (final error in <Object>[
        const SocketException('Connection refused'),
        TimeoutException('slow'),
        Exception('ClientException: Failed host lookup: x.supabase.co'),
      ]) {
        expect(friendlyAuthError(l, error), l.authOffline, reason: '$error');
      }
    });

    test('anything else is the generic failure, never the raw text', () {
      expect(
        friendlyAuthError(l, StateError('internal')),
        l.authGenericFailure,
      );
    });
  });

  group('form checks', () {
    test('passwords need eight characters', () {
      expect(passwordProblem(l, '1234567'), l.passwordUseAtLeast8);
      expect(passwordProblem(l, '12345678'), isNull);
    });

    test('emails are checked loosely, trimmed first', () {
      expect(emailProblem(l, '   '), l.enterYourEmail);
      expect(emailProblem(l, 'someone'), l.authNotAnEmail);
      expect(emailProblem(l, 'someone@localhost'), l.authNotAnEmail);
      expect(emailProblem(l, '  jin.wei+scandy@example.com '), isNull);
    });
  });
}
