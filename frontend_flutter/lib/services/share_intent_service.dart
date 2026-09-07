import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Receives receipt images shared into Scandy from other Android apps.
///
/// This is the Flutter port of `useIntent.js` + the `capacitor-plugin-send-intent`
/// wiring. The Vue version kept an `intentConsumed` flag because Home.vue could
/// remount and re-handle the same intent; here the stream is owned by one
/// long-lived service and each payload is emitted exactly once, so the flag is
/// unnecessary — [reset] tells the platform side we're done with it.
///
/// Emits [XFile] rather than a `dart:io` File so this compiles for web, where
/// the plugin has no implementation and [start] is a no-op.
class ShareIntentService {
  ShareIntentService();

  late final _controller =
      StreamController<XFile>.broadcast(onListen: _flushPending);
  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _started = false;

  /// Shares that arrived before anything was listening.
  ///
  /// [start] runs in `main()`, before `runApp`, so the share that cold-started
  /// the app is delivered while the widget tree does not yet exist — and a
  /// broadcast stream drops events that have no listener. That is the common
  /// case (share a receipt at an app that isn't running), and it silently did
  /// nothing. Queue those and replay them when the shell subscribes.
  final _pending = <XFile>[];

  /// Images shared into the app, whether it was already running or cold-started.
  Stream<XFile> get images => _controller.stream;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start() async {
    if (_started || !_supported) return;
    _started = true;

    try {
      // Shares that arrive while the app is alive.
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
        _emit,
        onError: (Object e) =>
            debugPrint('ShareIntentService: media stream error: $e'),
      );

      // The share that cold-started the app, if any.
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _emit(initial);
      // Without this the same payload is redelivered on the next resume.
      ReceiveSharingIntent.instance.reset();
    } catch (e) {
      // A missing platform implementation must not take the app down at
      // launch — sharing simply won't be available.
      debugPrint('ShareIntentService: unavailable ($e)');
    }
  }

  void _emit(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.path.isEmpty) continue;
      final file = XFile(f.path);
      if (_controller.hasListener) {
        _controller.add(file);
      } else {
        _pending.add(file);
      }
    }
  }

  void _flushPending() {
    if (_pending.isEmpty) return;
    final queued = List.of(_pending);
    _pending.clear();
    // A microtask, not a synchronous add: `onListen` fires from inside
    // `listen()`, which the shell calls during initState.
    scheduleMicrotask(() {
      for (final file in queued) {
        if (!_controller.isClosed) _controller.add(file);
      }
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
