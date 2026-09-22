/// Android platform SpeechRecognizer fallback.
///
/// This provider is intentionally network-agnostic: Android's installed
/// speech service handles microphone capture and recognition. It is used when
/// Sarvam credentials are unavailable or a Sarvam WebSocket drops, so voice
/// typing never gets stuck behind a WebSocketException.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../data/languages.dart';
import 'voice_engine.dart';

class AndroidSpeechProvider implements SpeechProvider {
  static const MethodChannel _control = MethodChannel('bhasha/speech');
  static const EventChannel _events = EventChannel('bhasha/speech_results');

  StreamSubscription<dynamic>? _subscription;
  void Function(VoiceResult)? _onResult;
  void Function(String)? _onError;
  bool _running = false;
  LanguagePack? _pack;

  @override
  Future<bool> initialize(LanguagePack pack) async {
    _pack = pack;
    try {
      return await _control.invokeMethod<bool>('hasMicPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void start(void Function(VoiceResult) onResult) {
    _onResult = onResult;
    if (_running) return;
    _running = true;
    _subscription = _events.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final text = (event['text'] as String? ?? '').trim();
        if (text.isNotEmpty) {
          _onResult?.call(VoiceResult(text, event['isFinal'] == true));
        }
        final error = (event['error'] as String? ?? '').trim();
        if (error.isNotEmpty) _onError?.call(error);
      },
      onError: (Object error) =>
          _onError?.call('Speech recognition unavailable'),
    );
    unawaited(
      _control
          .invokeMethod<void>('startSpeech', {
            'locale': _pack?.locale ?? 'en-IN',
          })
          .catchError((_) {
            _onError?.call('Speech recognition unavailable');
          }),
    );
  }

  @override
  Future<void> stop() async {
    _running = false;
    try {
      await _control.invokeMethod<void>('stopSpeech');
    } catch (_) {}
    await _subscription?.cancel();
    _subscription = null;
    _onResult = null;
  }

  @override
  void setScriptMode(ScriptMode mode) {}

  @override
  void setMicMode(MicMode mode) {}

  @override
  void setTranslateTarget(LanguagePack target) {}

  @override
  bool get hasNativeTranslateMode => false;

  @override
  void setErrorHandler(void Function(String message)? handler) {
    _onError = handler;
  }
}

/// Uses Sarvam when a key is available, with Android SpeechRecognizer as a
/// transparent fallback for missing credentials, quota errors, and transport
/// failures. This keeps the fast streaming path while making mic reliable in
/// ordinary APK installs where no private API key can be bundled safely.
class ResilientSpeechProvider implements SpeechProvider {
  ResilientSpeechProvider({
    required SpeechProvider primary,
    required SpeechProvider fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final SpeechProvider _primary;
  final SpeechProvider _fallback;
  SpeechProvider? _active;
  void Function(VoiceResult)? _onResult;
  void Function(String)? _onError;
  LanguagePack? _pack;
  ScriptMode _scriptMode = ScriptMode.native;
  MicMode _micMode = MicMode.autoMix;
  LanguagePack? _target;
  bool _fallbackStarted = false;

  @override
  Future<bool> initialize(LanguagePack pack) async {
    _pack = pack;
    _fallbackStarted = false;
    final primaryOk = await _primary.initialize(pack);
    final fallbackOk = await _fallback.initialize(pack);
    return primaryOk || fallbackOk;
  }

  @override
  void start(void Function(VoiceResult) onResult) {
    _onResult = onResult;
    _fallbackStarted = false;
    _wire(_primary);
    _active = _primary;
    _primary.start(onResult);
  }

  void _wire(SpeechProvider provider) {
    provider.setScriptMode(_scriptMode);
    provider.setMicMode(_micMode);
    if (_target != null) provider.setTranslateTarget(_target!);
    provider.setErrorHandler((message) {
      if (identical(provider, _primary) && !_fallbackStarted && _pack != null) {
        // Android SpeechRecognizer only transcribes one locale. It cannot
        // implement Sarvam Translate or Auto Mix; falling back here would
        // insert unrelated English text after a realtime API failure.
        if (_micMode == MicMode.autoMix || _micMode == MicMode.translate) {
          _onError?.call(message);
          return;
        }
        _fallbackStarted = true;
        unawaited(_primary.stop());
        _wire(_fallback);
        _active = _fallback;
        _fallback.start(_onResult ?? (_) {});
      } else {
        _onError?.call(message);
      }
    });
  }

  @override
  Future<void> stop() async {
    await _primary.stop();
    await _fallback.stop();
    _active = null;
    _onResult = null;
  }

  @override
  void setScriptMode(ScriptMode mode) {
    _scriptMode = mode;
    _primary.setScriptMode(mode);
    _fallback.setScriptMode(mode);
  }

  @override
  void setMicMode(MicMode mode) {
    _micMode = mode;
    _primary.setMicMode(mode);
    _fallback.setMicMode(mode);
  }

  @override
  void setTranslateTarget(LanguagePack target) {
    _target = target;
    _primary.setTranslateTarget(target);
    _fallback.setTranslateTarget(target);
  }

  @override
  bool get hasNativeTranslateMode => _active?.hasNativeTranslateMode ?? true;

  @override
  void setErrorHandler(void Function(String message)? handler) {
    _onError = handler;
    _wire(_primary);
    _wire(_fallback);
  }
}
