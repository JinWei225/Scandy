/// Reading a receipt when the device cannot.
///
/// On Android and iOS, ML Kit plus the rules in receipt_rules.dart answer most
/// scans in well under a second with no network at all -- that path is in
/// local_scanner.dart and is unchanged. This is the other half: what happens on
/// the web, where there is no ML Kit, and on a phone whose local read came back
/// incomplete.
///
/// That half is the `scan-receipt` Edge Function, which calls Gemini. It runs
/// server-side for one reason: the API key. A key shipped inside this app is
/// readable by anyone who opens the web bundle or decompiles the APK, and it
/// bills to whoever shipped it.
library;

import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceiptScanException implements Exception {
  ReceiptScanException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class CloudReceiptScanner {
  /// Returns the same `{date, time, amount}` shape the on-device path produces,
  /// so the transaction form is prefilled identically either way.
  Future<Map<String, dynamic>> scan(XFile file);
}

/// Posts the image to the `scan-receipt` Edge Function.
class SupabaseCloudScanner implements CloudReceiptScanner {
  const SupabaseCloudScanner();

  @override
  Future<Map<String, dynamic>> scan(XFile file) async {
    final bytes = await file.readAsBytes();
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'scan-receipt',
        // Raw bytes, not base64 and not multipart: invoke() sends a Uint8List
        // as application/octet-stream, and the function encodes once on its
        // side for Gemini. Base64 here would put a third more over the wire
        // from a phone.
        body: bytes,
        headers: {'x-image-mime': _mimeOf(file.name)},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      throw ReceiptScanException('The scanner sent back something unreadable.');
    } on FunctionException catch (e) {
      // The function answers every failure with {"error": "..."} written for a
      // person -- the daily cap, an unreadable photo, a signed-out session.
      final detail = e.details;
      final message = detail is Map && detail['error'] is String
          ? detail['error'] as String
          : 'Could not scan that receipt.';
      throw ReceiptScanException(message);
    } catch (e) {
      final text = '$e';
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('TimeoutException') ||
          text.contains('Failed host lookup')) {
        throw ReceiptScanException(
            'Cannot reach the scanner right now. Check your connection.');
      }
      throw ReceiptScanException('Could not scan that receipt.');
    }
  }

  /// Gemini needs the real type; a wrong one is rejected outright.
  static String _mimeOf(String filename) {
    final ext =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }
}
