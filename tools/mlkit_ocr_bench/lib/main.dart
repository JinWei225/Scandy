// Benchmark harness: runs Google ML Kit text recognition over images pushed to
// the device and writes the detections out as JSON.
//
// It is not an app anyone uses — it exists so the OCR half of the Scandy
// pipeline can be measured on-device against Apple Vision on the Mac. See
// backend/bench/compare_pipelines.py for the comparison it feeds.
//
//   adb push <images> /sdcard/Android/data/com.scandy.mlkit_ocr_bench/files/in/
//   (launch the app, wait for DONE)
//   adb pull /sdcard/Android/data/com.scandy.mlkit_ocr_bench/files/out/mlkit_ocr.json
//
// The app's own external files directory needs no runtime permission, which is
// why input and output both live there rather than in Downloads.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const BenchApp());

class BenchApp extends StatelessWidget {
  const BenchApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BenchPage(),
      );
}

class BenchPage extends StatefulWidget {
  const BenchPage({super.key});

  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<BenchPage> {
  final List<String> _log = [];
  bool _running = false;
  bool _done = false;

  void _say(String line) {
    // ignore: avoid_print
    print('[bench] $line');
    setState(() => _log.add(line));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _done = false;
      _log.clear();
    });

    try {
      final base = await getExternalStorageDirectory();
      if (base == null) {
        _say('ERROR: no external storage directory');
        return;
      }
      final inDir = Directory('${base.path}/in');
      final outDir = Directory('${base.path}/out');
      // Both directories are created here, by the app, rather than over adb: a
      // directory made by the shell user is not readable by this package, which
      // fails later as an opaque "Permission denied" on listSync.
      inDir.createSync(recursive: true);
      outDir.createSync(recursive: true);

      final images = inDir
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      _say('${images.length} image(s) in ${inDir.path}');

      // The Latin model is the closest match to how Apple Vision is configured
      // on the server (en-US). The Chinese model also covers Latin, so running
      // both shows what the Chinese-language receipts cost.
      final scripts = {
        'latin': TextRecognitionScript.latin,
        'chinese': TextRecognitionScript.chinese,
      };

      final results = <String, dynamic>{};
      final outFile = File('${outDir.path}/mlkit_ocr.json');

      // Written after every script, not once at the end. Only the Latin model
      // ships with the app; the others are fetched through Play Services and can
      // fail or take the process down with them, and losing a completed pass to
      // a later one's failure would mean re-running everything.
      void flush() {
        outFile.writeAsStringSync(const JsonEncoder.withIndent('  ')
            .convert({'device': {'os': Platform.operatingSystemVersion}, 'scripts': results}));
      }

      for (final entry in scripts.entries) {
        final TextRecognizer recognizer;
        try {
          recognizer = TextRecognizer(script: entry.value);
        } catch (e) {
          _say('${entry.key}: recognizer unavailable — $e');
          continue;
        }
        final perImage = <String, dynamic>{};
        final stopwatchTotal = Stopwatch()..start();

        for (var i = 0; i < images.length; i++) {
          final file = images[i];
          final name = file.path.split('/').last;
          try {
            final size = await _imageSize(file);
            final sw = Stopwatch()..start();
            final recognised =
                await recognizer.processImage(InputImage.fromFilePath(file.path));
            sw.stop();

            final lines = <Map<String, dynamic>>[];
            for (final block in recognised.blocks) {
              for (final line in block.lines) {
                final box = line.boundingBox;
                lines.add({
                  'text': line.text,
                  // ML Kit does not always report a line confidence; the
                  // pipeline treats anything >= 0.5 as usable, so an unknown
                  // confidence must not silently drop the line.
                  'conf': line.confidence ?? 1.0,
                  'x0': box.left,
                  'cy': box.top + box.height / 2.0,
                });
              }
            }
            perImage[name] = {
              'lines': lines,
              'width': size.width,
              'height': size.height,
              'ms': sw.elapsedMilliseconds,
            };
          } catch (e) {
            perImage[name] = {'error': '$e'};
          }
          if (i % 10 == 0 || i == images.length - 1) {
            _say('${entry.key}: ${i + 1}/${images.length}');
          }
        }

        stopwatchTotal.stop();
        results[entry.key] = {
          'images': perImage,
          'total_ms': stopwatchTotal.elapsedMilliseconds,
        };
        flush();
        _say('${entry.key}: done in ${stopwatchTotal.elapsedMilliseconds} ms, saved');
        try {
          await recognizer.close();
        } catch (e) {
          _say('${entry.key}: close failed — $e');
        }
        // Give the native side a moment to tear down before the next model is
        // loaded; back-to-back recognizers were enough to end the process.
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }

      flush();
      _say('wrote ${outFile.path}');
      File('${outDir.path}/DONE').writeAsStringSync('ok');
      setState(() => _done = true);
    } catch (e, st) {
      _say('FAILED: $e');
      _say('$st');
    } finally {
      setState(() => _running = false);
    }
  }

  Future<ui.Size> _imageSize(File file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final size =
        ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    frame.image.dispose();
    codec.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ML Kit OCR bench'),
        backgroundColor: _done ? Colors.green : null,
      ),
      body: Column(
        children: [
          if (_running) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(_log[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: _running ? null : _run,
                child: Text(_done ? 'Run again' : 'Run'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
