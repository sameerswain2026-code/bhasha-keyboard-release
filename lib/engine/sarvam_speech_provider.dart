/// Sarvam AI real-time streaming speech provider.
///
/// Connects to Sarvam's Speech-to-Text WebSocket (saaras:v3) and streams
/// microphone PCM audio for near-instant transcription in all 22 Indian
/// languages + English. Output script follows the keyboard's selected
/// ScriptMode: `transcribe` mode returns native script, `translit` mode
/// returns Romanized text.
///
/// Reliability:
///  - 5-key pool with automatic failover rotation (auth/quota/rate-limit
///    errors rotate to the next healthy key and reconnect mid-session).
///  - Flush signal on stop so buffered tail audio is finalized, not lost.
///  - All internal errors are swallowed into clean lifecycle states.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../data/languages.dart';
import 'mic_source.dart';
import 'sarvam_keys.dart';
import 'voice_engine.dart';

class SarvamSpeechProvider implements SpeechProvider {
  SarvamSpeechProvider({
    required this.micSource,
    SarvamKeyPool? keyPool,
    this.sampleRate = 16000,
  }) : _pool = keyPool ?? SarvamKeyPool.production();

  final MicAudioSource micSource;
  final SarvamKeyPool _pool;
  final int sampleRate;

  static const String _wsBase = 'wss://api.sarvam.ai/speech-to-text/ws';
  static const String _model = 'saaras:v3';

  LanguagePack? _pack;
  ScriptMode _scriptMode = ScriptMode.native;
  MicMode _micMode = MicMode.transcribe;
  LanguagePack? _translateTarget;
  WebSocket? _ws;
  StreamSubscription<List<int>>? _micSub;
  StreamSubscription<dynamic>? _wsSub;
  void Function(VoiceResult)? _onResult;
  bool _running = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnects = 6; // enough to try every key + retry

  @override
  void setScriptMode(ScriptMode mode) {
    _scriptMode = mode;
  }

  @override
  void setMicMode(MicMode mode) {
    _micMode = mode;
  }

  @override
  void setTranslateTarget(LanguagePack target) {
    _translateTarget = target;
  }

  /// The Translate mode target most recently set via [setTranslateTarget].
  /// Sarvam's server-side `translate` mode always outputs English
  /// regardless of this value (see [_connectAndStream]); exposed so
  /// callers/tests can confirm the value was stored even though the wire
  /// protocol itself has no arbitrary-target parameter yet.
  LanguagePack? get translateTargetOverride => _translateTarget;

  @override
  bool get hasNativeTranslateMode => true;

  @override
  Future<bool> initialize(LanguagePack pack) async {
    _pack = pack;
    _reconnectAttempts = 0;
    // Fail fast with a clean state if the mic permission is missing.
    try {
      return await micSource.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  void start(void Function(VoiceResult) onResult) {
    _onResult = onResult;
    if (_running) return; // continuous session: socket already streaming
    _running = true;
    _connectAndStream();
  }

  Future<void> _connectAndStream() async {
    final pack = _pack;
    if (pack == null || !_running) return;

    // Sarvam's saaras:v3 model exposes several server-side output modes
    // directly over this same WebSocket (see Sarvam Streaming STT docs):
    //   transcribe - native script, source language (default)
    //   translit   - Romanized transcription of the source language
    //   translate  - speech translated to English, returned in English
    // Mic mode picks the mode that matches the feature's contract:
    //  - transcribe: output script follows the keyboard's Native/Roman
    //    setting - translit for Roman on a non-Latin language, else
    //    transcribe (native script).
    //  - autoMix: always Romanized, regardless of spoken language or the
    //    current script-mode setting (the controller also forces
    //    ScriptMode.roman for this mode; pinned here too so mid-session
    //    mode switches take effect immediately).
    //  - translate: real speech-to-English translation done server-side
    //    by Sarvam (far higher quality than pivoting through the app's
    //    small offline phrase dictionary). The English result's script
    //    is then adapted client-side in KeyboardController: Roman mode
    //    keeps it as English text, Native mode phonetically renders that
    //    English translation in the active language's script.
    final String mode;
    if (_micMode == MicMode.autoMix) {
      mode = pack.isLatin ? 'transcribe' : 'translit';
    } else if (_micMode == MicMode.translate) {
      mode = 'translate';
    } else {
      mode = _scriptMode == ScriptMode.roman && !pack.isLatin
          ? 'translit'
          : 'transcribe';
    }

    final uri =
        '$_wsBase'
        '?language-code=${pack.sarvamCode}'
        '&model=$_model'
        '&mode=$mode'
        '&sample_rate=$sampleRate'
        '&input_audio_codec=pcm_s16le'
        '&high_vad_sensitivity=true'
        '&vad_signals=false'
        '&flush_signal=true';

    final key = _pool.current;
    try {
      final ws = await WebSocket.connect(
        uri,
        headers: {'api-subscription-key': key},
      ).timeout(const Duration(seconds: 8));
      _ws = ws;
      _pool.markHealthy(key);
      _reconnectAttempts = 0;

      _wsSub = ws.listen(
        (message) => _handleServerMessage(message, key),
        onError: (_) => _handleTransportDrop(key),
        onDone: () => _handleSocketClosed(ws, key),
        cancelOnError: true,
      );

      await _startMicPump(ws);
    } catch (e) {
      _failoverAndRetry(key, message: e.toString());
    }
  }

  Future<void> _startMicPump(WebSocket ws) async {
    // Reuse an already-running mic stream across reconnects.
    if (_micSub != null) return;
    try {
      final stream = await micSource.start();
      _micSub = stream.listen((chunk) {
        final sock = _ws;
        if (sock == null || sock.readyState != WebSocket.open) return;
        try {
          sock.add(
            jsonEncode({
              'audio': {
                'data': base64Encode(chunk),
                'sample_rate': sampleRate,
                'encoding': 'audio/wav',
              },
            }),
          );
        } catch (_) {}
      });
    } catch (_) {
      // Mic failure: end cleanly; engine surfaces "unavailable".
      _running = false;
    }
  }

  void _handleServerMessage(dynamic message, String key) {
    if (message is! String) return;
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = parsed['type'] as String?;
    if (type == 'data') {
      final data = parsed['data'] as Map<String, dynamic>?;
      final transcript = (data?['transcript'] as String?)?.trim() ?? '';
      if (transcript.isNotEmpty) {
        // Server emits finalized utterance segments.
        _onResult?.call(VoiceResult(transcript, true));
      }
    } else if (type == 'error') {
      final data = parsed['data'] as Map<String, dynamic>?;
      final msg = data?['message'] as String? ?? '';
      if (SarvamKeyPool.isKeyError(message: msg)) {
        _failoverAndRetry(key, message: msg);
      }
      // Non-key errors (e.g. validation) are swallowed; the lifecycle
      // engine's silence timeout will close the session cleanly.
    }
  }

  void _handleSocketClosed(WebSocket ws, String key) {
    if (!_running) return;
    final code = ws.closeCode;
    if (SarvamKeyPool.isKeyError(closeCode: code)) {
      _failoverAndRetry(key, closeCode: code);
    } else {
      _handleTransportDrop(key);
    }
  }

  void _handleTransportDrop(String key) {
    // Network blip: reconnect with the same key (bounded retries).
    if (!_running) return;
    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnects) {
      _running = false;
      return;
    }
    _teardownSocket();
    Future<void>.delayed(
      Duration(milliseconds: 200 * _reconnectAttempts),
      _connectAndStream,
    );
  }

  void _failoverAndRetry(String key, {String? message, int? closeCode}) {
    if (!_running) return;
    _pool.markFailed(key);
    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnects) {
      _running = false;
      return;
    }
    _teardownSocket();
    // Rotate immediately: next healthy key takes over the live session.
    Future<void>.delayed(const Duration(milliseconds: 120), _connectAndStream);
  }

  void _teardownSocket() {
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  @override
  Future<void> stop() async {
    _running = false;
    // Flush buffered audio so the spoken tail is finalized before close.
    final sock = _ws;
    if (sock != null && sock.readyState == WebSocket.open) {
      try {
        sock.add(jsonEncode({'type': 'flush'}));
        // Give the server a brief window to emit the final transcript.
        await Future<void>.delayed(const Duration(milliseconds: 600));
      } catch (_) {}
    }
    await _micSub?.cancel();
    _micSub = null;
    try {
      await micSource.stop();
    } catch (_) {}
    _teardownSocket();
    _onResult = null;
  }
}
