/// Reading a receipt on the device, without the network.
///
/// ML Kit recognises the text and [extractFields] reads the fields out of it.
/// Both halves are on-device, so a scan works with no network at all — which is
/// the point: the share-to-Scandy path used to sit waiting for Tailscale before
/// it could do anything.
///
/// The cloud path is the fallback: the `scan-receipt` Edge Function, which asks
/// Gemini. It is reached only when the rules left a field empty, and its answer
/// then supersedes the partial local one; when it cannot be reached, a partial
/// local answer still beats failing the scan outright. That orchestration lives
/// in `_ScanJob` in ui/shell/app_shell.dart, the call itself in
/// receipt_scanner.dart.
///
/// ML Kit is Android and iOS only. The implementation is selected by conditional
/// import so the web build, which has no ML Kit, still compiles — there
/// [LocalScanner.isAvailable] is false and every scan takes the cloud path.
library;

import 'package:cross_file/cross_file.dart';

import 'receipt_rules.dart';

// Only re-exported, not used here: local_scanner.dart defines the contract and
// the platform file supplies the factory that satisfies it.
export 'local_scanner_unsupported.dart'
    if (dart.library.io) 'local_scanner_mlkit.dart' show createLocalScanner;

/// What an on-device scan produced.
class LocalScanResult {
  const LocalScanResult({required this.fields, required this.text});

  final ReceiptFields fields;

  /// The assembled OCR text. Kept so a miss can be diagnosed — and logged —
  /// without re-running anything.
  final String text;
}

abstract class LocalScanner {
  /// Whether this platform can scan without the server.
  bool get isAvailable;

  /// Reads [file] on device. Returns null when scanning is not available here.
  ///
  /// Throws only for genuinely unexpected failures; an image it simply cannot
  /// read comes back as a [LocalScanResult] with empty fields, because that is
  /// a result the caller can act on rather than an error.
  Future<LocalScanResult?> scan(XFile file);

  /// Releases the recogniser. Safe to call more than once.
  Future<void> dispose();
}

/// A scanner that never scans — the web build, and anything else without ML Kit.
class UnavailableLocalScanner implements LocalScanner {
  const UnavailableLocalScanner();

  @override
  bool get isAvailable => false;

  @override
  Future<LocalScanResult?> scan(XFile file) async => null;

  @override
  Future<void> dispose() async {}
}

/// Formats on-device fields into the shape `/api/upload` returns, so the
/// transaction form is prefilled identically whichever path produced them.
Map<String, dynamic> prefillFrom(ReceiptFields fields, {String currency = 'RM'}) => {
      'date': fields.date,
      'time': fields.time,
      'amount': fields.amount == null ? null : '$currency ${fields.amount}',
    };
