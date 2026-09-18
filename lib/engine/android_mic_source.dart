/// Android microphone source: streams 16kHz PCM16 chunks from the
/// native AudioRecord (VOICE_RECOGNITION source) over an EventChannel.
library;

import 'package:flutter/services.dart';

import 'mic_source.dart';

class AndroidMicSource implements MicAudioSource {
  static const MethodChannel _system = MethodChannel('bhasha/system');
  static const EventChannel _mic = EventChannel('bhasha/mic');

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
    final ok = await _system.invokeMethod<bool>('startMic');
    if (ok != true) {
      throw StateError('Microphone unavailable');
    }
    return _mic.receiveBroadcastStream().map(
      (event) => (event as List).cast<int>(),
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _system.invokeMethod('stopMic');
    } catch (_) {}
  }
}
