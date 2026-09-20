/// Android microphone source: streams 16kHz PCM16 chunks from the
/// native AudioRecord (VOICE_RECOGNITION source) over an EventChannel.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'mic_source.dart';

class AndroidMicSource implements MicAudioSource {
  static const MethodChannel _system = MethodChannel('bhasha/system');
  static const EventChannel _mic = EventChannel('bhasha/mic');
  StreamSubscription<dynamic>? _nativeSubscription;
  StreamController<List<int>>? _controller;

  @override
  Future<bool> hasPermission() async {
    try {
      final granted = await _system.invokeMethod<bool>('hasMicPermission');
      if (granted == true) return true;
      // One-shot request from the host activity (no-op inside the IME).
      final after = await _system.invokeMethod<bool>('requestMicPermission');
      return after == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Stream<List<int>>> start() async {
    if (_controller != null) return _controller!.stream;

    // Install the native EventChannel listener before starting AudioRecord.
    // The controller buffers the short interval before Sarvam subscribes to
    // the returned stream, so the first spoken syllable is not lost.
    final controller = StreamController<List<int>>();
    _controller = controller;
    _nativeSubscription = _mic.receiveBroadcastStream().listen(
      (event) {
        if (!controller.isClosed) controller.add((event as List).cast<int>());
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    final ok = await _system.invokeMethod<bool>('startMic');
    if (ok != true) {
      await _nativeSubscription?.cancel();
      _nativeSubscription = null;
      await controller.close();
      _controller = null;
      throw StateError('Microphone unavailable');
    }
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    await _controller?.close();
    _controller = null;
    try {
      await _system.invokeMethod('stopMic');
    } catch (_) {}
  }
}
