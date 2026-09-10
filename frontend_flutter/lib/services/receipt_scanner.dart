/// Reading a receipt when the device cannot.
///
/// On Android and iOS, ML Kit plus the rules in receipt_rules.dart answer most
/// scans in well under a second with no network at all -- that path is in
/// local_scanner.dart and is unchanged. This is the other half: what happens on
/// the web, where there is no ML Kit, and on a phone whose local read came back
/// incomplete.
///
/// Until Phase 05 that half does not exist. The Flask backend used to provide
/// it, running Apple Vision and a small extraction model on the Mac mini, and
/// removing that server is the point of the migration. Its replacement is a
/// Supabase Edge Function calling a hosted vision model -- which needs an API
/// key that must never ship inside this app, hence a server-side function
/// rather than a direct call from here.
///
/// Failing loudly with an accurate sentence is the honest state in between. The
/// alternative -- a silent no-op -- would look like a scanner that reads every
/// receipt as blank.
library;

import 'package:cross_file/cross_file.dart';

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

/// The stand-in that ships until the Edge Function exists.
class UnavailableCloudScanner implements CloudReceiptScanner {
  const UnavailableCloudScanner();

  @override
  Future<Map<String, dynamic>> scan(XFile file) async {
    throw ReceiptScanException(
      'Scanning on this device is not available yet — type the amount in and '
      'it will be saved the same way.',
    );
  }
}
