// Proves the on-device scanner works inside the real app, on a real device.
//
// The rules themselves are covered by test/receipt_rules_test.dart, which runs
// them against 104 cases of real captured OCR — including ML Kit's own output
// from a phone. What that cannot cover is the wiring: that the ML Kit plugin is
// actually reachable from this app, that its bounding boxes feed assembleText in
// the right coordinate space, and that the whole path returns usable fields.
//
// So this test draws its own receipt and scans it. Nothing is pushed to the
// device, which matters for two reasons: `flutter test integration_test`
// uninstalls the app when it finishes and takes any pushed files with it, and a
// fixture of real receipts has no business being in the repository.
//
//   flutter test integration_test/local_scanner_test.dart -d <device-id>
//
// The device must be unlocked. On a platform without ML Kit the test asserts the
// scanner reports itself unavailable, which is the behaviour the web build needs.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scandy/services/local_scanner.dart';

/// Renders a payment screen in the shape the real ones take: a headline amount,
/// then labelled rows. Black on white at a generous size, because this is
/// testing the plumbing, not ML Kit's tolerance for bad photographs.
Future<Uint8List> drawReceipt(List<(String, String)> rows, String headline) async {
  const width = 900.0;
  const rowHeight = 90.0;
  final height = 260.0 + rows.length * rowHeight;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
  canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFFFFFFF));

  void text(String value, double x, double y, {double size = 40, bool bold = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: const Color(0xFF000000),
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  text('Payment successful', 60, 60, size: 44);
  text(headline, 60, 140, size: 64, bold: true);

  var y = 280.0;
  for (final (label, value) in rows) {
    text(label, 60, y, size: 38);
    text(value, 420, y, size: 38);
    y += rowHeight;
  }

  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<XFile> writeTemp(Uint8List bytes, String name) async {
  final file = File('${Directory.systemTemp.path}/$name');
  await file.writeAsBytes(bytes);
  return XFile(file.path);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads a receipt end to end, on device, with no server',
      (WidgetTester tester) async {
    final scanner = createLocalScanner();

    if (!scanner.isAvailable) {
      // The web build and anything else without ML Kit must say so rather than
      // throw, because that is what makes the server fallback kick in.
      expect(await scanner.scan(await writeTemp(Uint8List(0), 'noop.png')), isNull);
      return;
    }

    final bytes = await drawReceipt(const [
      ('Merchant', 'EXAMPLE NOODLE HOUSE'),
      ('Transaction Type', 'DuitNow QR'),
      ('Date/Time', '09/07/2026 12:10:57'),
      ('Payment Method', 'eWallet Balance'),
    ], 'RM 12.00');

    final stopwatch = Stopwatch()..start();
    final result = await scanner.scan(await writeTemp(bytes, 'scandy_probe.png'));
    stopwatch.stop();

    expect(result, isNotNull, reason: 'scanner returned nothing');
    // ignore: avoid_print
    print('on-device scan: ${stopwatch.elapsedMilliseconds} ms\n${result!.text}');

    expect(result.fields.date, '09/07/2026');
    expect(result.fields.time, '12:10:57');
    expect(result.fields.amount, '12.00');
    expect(result.fields.isComplete, isTrue);

    await scanner.dispose();
  });

  testWidgets('a screen with no date comes back partial, not wrong',
      (WidgetTester tester) async {
    final scanner = createLocalScanner();
    if (!scanner.isAvailable) return;

    // The amount is readable; nothing on the screen is a transaction date. The
    // scanner must say so, because that empty field is exactly what makes the
    // dialog ask the server instead of inventing something.
    final bytes = await drawReceipt(const [
      ('Merchant', 'EXAMPLE MART'),
      ('Status', 'Successful'),
    ], 'RM 42.50');

    final result = await scanner.scan(await writeTemp(bytes, 'scandy_partial.png'));
    expect(result, isNotNull);
    expect(result!.fields.amount, '42.50');
    expect(result.fields.date, isNull);
    expect(result.fields.isComplete, isFalse);
    expect(result.fields.missing, ['date', 'time']);

    await scanner.dispose();
  });
}
