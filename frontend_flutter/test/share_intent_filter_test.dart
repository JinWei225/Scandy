import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/services/share_intent_service.dart';

/// The password-reset deep link arrives through the same plugin as a shared
/// receipt, because it listens for ACTION_VIEW as well as ACTION_SEND. Sending
/// it to the scanner ended a successful password reset with "Couldn't read
/// that one" and a PathNotFoundException naming the callback URL.
void main() {
  group('shared payloads that are actually files', () {
    test('accepts what a real share looks like', () {
      for (final path in [
        '/data/user/0/com.jinwei.scandy/cache/receipt.jpg',
        '/storage/emulated/0/DCIM/Camera/IMG_20260910.jpg',
        'content://media/external/images/media/1234',
        'file:///tmp/receipt.png',
      ]) {
        expect(debugIsShareableFile(path), isTrue, reason: path);
      }
    });

    test('rejects the auth deep link and anything else with a scheme', () {
      for (final path in [
        'com.jinwei.scandy://login-callback?code=5d17311c-c9c1-42ad-a63d',
        'com.jinwei.scandy://login-callback',
        'https://example.com/receipt.jpg',
        'mailto:someone@example.com',
      ]) {
        expect(debugIsShareableFile(path), isFalse, reason: path);
      }
    });
  });
}
