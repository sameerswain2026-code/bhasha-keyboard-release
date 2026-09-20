/// Android microphone source: streams 16kHz PCM16 chunks from the
/// native AudioRecord (VOICE_RECOGNITION source) over an EventChannel.
library;

import 'package:flutter/services.dart';
import 'dart:async';

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
    // Keep a listener and a small buffer alive before AudioRecord starts;
    // short utterances must not lose their first PCM chunks on the IME.
    final controller = StreamController<List<int>>();
    _controller = controller;
    _nativeSubscription = _mic.receiveBroadcastStream().listen(
      (event) => controller.add((event as List).cast<int>()),
      onError: controller.addError,
      onDone: controller.close,
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
    try {
      await _system.invokeMethod('stopMic');
    } catch (_) {}
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    await _controller?.close();
    _controller = null;
  }
}
