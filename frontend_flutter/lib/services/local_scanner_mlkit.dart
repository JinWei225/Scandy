/// On-device scanning with Google ML Kit.
///
/// Selected by the conditional import in local_scanner.dart wherever `dart:io`
/// exists. ML Kit itself only ships for Android and iOS, so the platform is
/// checked again at runtime — a macOS or Linux build would otherwise fail
/// inside the plugin rather than falling back cleanly.
///
/// Measured on the phone this was built against: 136 ms per image, and the
/// rules read all three fields correctly on all 50 captured screenshots.
library;

import 'dart:io' show File, Platform;
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'local_scanner.dart';
import 'receipt_rules.dart';

LocalScanner createLocalScanner() =>
    (Platform.isAndroid || Platform.isIOS) ? MlKitScanner() : const UnavailableLocalScanner();

class MlKitScanner implements LocalScanner {
  MlKitScanner();

  TextRecognizer? _recognizer;

  @override
  bool get isAvailable => true;

  // Created on first use and kept: the recogniser is cheap to hold and loading
  // it per scan would show up on the share-to-Scandy path, which is the one
  // that needs to feel instant.
  TextRecognizer get _text =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<LocalScanResult?> scan(XFile file) async {
    final path = file.path;
    if (path.isEmpty) return null;

    final height = await _imageHeight(File(path));
    if (height == null) return null;

    final recognised = await _text.processImage(InputImage.fromFilePath(path));

    final lines = <OcrLine>[];
    for (final block in recognised.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        lines.add(OcrLine(
          text: line.text,
          // ML Kit does not always report a per-line confidence. The pipeline
          // drops anything below 0.5, so an unknown confidence must not
          // silently discard a line that was read fine.
          confidence: line.confidence ?? 1.0,
          x0: box.left.toDouble(),
          centreY: box.top + box.height / 2.0,
        ));
      }
    }

    final text = assembleText(lines, height);
    return LocalScanResult(fields: extractFields(text), text: text);
  }

  /// Decoded rather than assumed: [assembleText] groups rows within 1% of the
  /// image height, and ML Kit reports boxes in image pixels.
  Future<double?> _imageHeight(File file) async {
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      codec = await ui.instantiateImageCodec(await file.readAsBytes());
      frame = await codec.getNextFrame();
      return frame.image.height.toDouble();
    } catch (_) {
      return null;
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}
