/// Voice typing subsystem - isolated engine with a strict lifecycle:
/// IDLE -> INITIALIZING -> LISTENING -> (partial/final transcription)
/// -> STOPPING -> IDLE
///
/// On Web preview the platform speech service is simulated so the full
/// lifecycle (partial results, continuous speech, silence auto-stop,
/// manual stop, clean cancellation) can be exercised end-to-end.
/// On Android the same abstraction binds to the platform recognizer.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/languages.dart';

enum VoiceState { idle, initializing, listening, stopping, error }

/// Voice-typing output mode.
/// - [transcribe]: normal recognition; output script follows the
///   keyboard's Native/Roman setting (existing default behavior).
/// - [translate]: recognized speech is translated (to English) and the
///   translated result's script adapts to the Native/Roman setting -
///   Roman keeps the English text as-is, Native phonetically renders it
///   in the current language's script.
/// - [autoMix]: recognized speech is always romanized regardless of the
///   spoken language or the keyboard's current script setting.
enum MicMode { transcribe, translate, autoMix }

class VoiceResult {
  final String text;
  final bool isFinal;
  const VoiceResult(this.text, this.isFinal);
}

/// Abstraction over the actual speech provider.
abstract class SpeechProvider {
  Future<bool> initialize(LanguagePack pack);
  void start(void Function(VoiceResult) onResult);
  Future<void> stop();

  /// Informs the provider of the desired output script for recognized
  /// text (native script vs Roman transliteration). Optional.
  void setScriptMode(ScriptMode mode);

  /// Informs the provider of the desired mic mode (transcribe / translate
  /// / auto-mix). Optional - providers that don't support server-side
  /// mode switching may treat this as a no-op and let the caller apply
  /// post-processing instead.
  void setMicMode(MicMode mode);

  /// Informs the provider of the Translate mode target language. Optional
  /// - Sarvam's server-side `translate` mode only ever outputs English
  /// regardless of this value (there is no server-side EN->target step),
  /// so providers may treat this as a no-op and let the caller pivot
  /// English -> target client-side as a fallback. Stored anyway so a
  /// future provider/model with real arbitrary-target support can use it.
  void setTranslateTarget(LanguagePack target);

  /// True if this provider performs real speech -> English translation
  /// itself (e.g. Sarvam's `translate` output mode) when in
  /// [MicMode.translate]. When false, the caller must translate the
  /// returned (source-language) text to English itself as a fallback.
  bool get hasNativeTranslateMode;
}

/// Simulated provider used on web preview: emits progressive partial
/// results word-by-word like a streaming recognizer, per language.
class SimulatedSpeechProvider implements SpeechProvider {
  Timer? _timer;
  LanguagePack? _pack;

  @override
  void setScriptMode(ScriptMode mode) {}

  @override
  void setMicMode(MicMode mode) {}

  @override
  void setTranslateTarget(LanguagePack target) {}

  @override
  bool get hasNativeTranslateMode => false;
  int _wordIndex = 0;
  int _phraseIndex = 0;

  /// Phrases emitted in the current session. After [maxPhrasesPerSession]
  /// the provider goes silent, letting the engine's silence auto-stop
  /// trigger - mirrors a real user finishing speaking.
  int _sessionPhrases = 0;
  static const int maxPhrasesPerSession = 2;

  static const Map<String, List<String>> _phrases = {
    'en': [
      'hello how are you doing today',
      'this keyboard supports voice typing',
      'see you tomorrow at the meeting',
    ],
    'hi': [
      'नमस्ते आप कैसे हैं',
      'यह कीबोर्ड आवाज़ से टाइप करता है',
      'कल मिलते हैं धन्यवाद',
    ],
    'bn': ['নমস্কার আপনি কেমন আছেন', 'এই কীবোর্ড ভয়েস টাইপিং সমর্থন করে'],
    'ta': ['வணக்கம் எப்படி இருக்கிறீர்கள்', 'இந்த விசைப்பலகை குரல் தட்டச்சு'],
    'te': ['నమస్తే మీరు ఎలా ఉన్నారు', 'ఈ కీబోర్డ్ వాయిస్ టైపింగ్'],
    'mr': ['नमस्कार तुम्ही कसे आहात', 'हा कीबोर्ड व्हॉइस टायपिंग करतो'],
    'gu': ['નમસ્તે તમે કેમ છો', 'આ કીબોર્ડ વૉઇસ ટાઇપિંગ કરે છે'],
    'kn': ['ನಮಸ್ಕಾರ ನೀವು ಹೇಗಿದ್ದೀರಿ', 'ಈ ಕೀಬೋರ್ಡ್ ಧ್ವನಿ ಟೈಪಿಂಗ್'],
    'ml': ['നമസ്കാരം സുഖമാണോ', 'ഈ കീബോർഡ് വോയ്സ് ടൈപ്പിംഗ്'],
    'pa': ['ਸਤ ਸ੍ਰੀ ਅਕਾਲ ਤੁਸੀਂ ਕਿਵੇਂ ਹੋ', 'ਇਹ ਕੀਬੋਰਡ ਵੌਇਸ ਟਾਈਪਿੰਗ ਕਰਦਾ ਹੈ'],
    'ur': ['سلام آپ کیسے ہیں', 'یہ کی بورڈ وائس ٹائپنگ کرتا ہے'],
    'or': ['ନମସ୍କାର ଆପଣ କେମିତି ଅଛନ୍ତି'],
    'as': ['নমস্কাৰ আপুনি কেনে আছে'],
    'ne': ['नमस्ते तपाईं कस्तो हुनुहुन्छ'],
  };

  @override
  Future<bool> initialize(LanguagePack pack) async {
    _pack = pack;
    _sessionPhrases = 0;
    // Simulate service warm-up latency.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return true;
  }

  @override
  void start(void Function(VoiceResult) onResult) {
    if (_sessionPhrases >= maxPhrasesPerSession) {
      // Simulated silence: emit nothing so silence auto-stop fires.
      return;
    }
    _sessionPhrases++;
    final phrases = _phrases[_pack?.id] ?? _phrases['en']!;
    final phrase = phrases[_phraseIndex % phrases.length];
    _phraseIndex++;
    final words = phrase.split(' ');
    _wordIndex = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (_wordIndex < words.length) {
        _wordIndex++;
        final partial = words.take(_wordIndex).join(' ');
        final isFinal = _wordIndex == words.length;
        onResult(VoiceResult(partial, isFinal));
        if (isFinal) t.cancel();
      }
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }
}

/// Central voice engine coordinating lifecycle + silence auto-stop.
class VoiceEngine extends ChangeNotifier {
  VoiceEngine({
    SpeechProvider? provider,
    this.silenceTimeout = defaultSilenceTimeout,
  }) : _provider = provider ?? SimulatedSpeechProvider();

  /// The engine's original/default mic-silence auto-stop window - used
  /// as the restore value by callers that temporarily widen
  /// [silenceTimeout] (see the setter below) and want to return to
  /// stock behavior afterwards.
  /// Long inactivity guard only; active speech always re-arms this timer.
  /// The recognizer's VAD/final events remain the primary speech boundary.
  // Keep listening through natural pauses while the user is speaking;
  // manual key interaction is handled separately by the controller.
  /// Stop after ten seconds with no partial/final speech activity. A new
  /// result re-arms the timer, so continuous speech keeps the session alive.
  static const Duration defaultSilenceTimeout = Duration(seconds: 10);

  final SpeechProvider _provider;

  /// How long the mic can sit silent before the session auto-stops.
  /// Mutable (rather than `final`) so a caller can temporarily widen
  /// this window for a specific purpose - e.g. [KeyboardController]
  /// widens it while buffering a multi-chunk AI voice command so the
  /// user's configured "Command Listening Timeout" (which can exceed
  /// this engine's own default) actually gets to elapse instead of the
  /// mic silently cutting the session first - then restores
  /// [defaultSilenceTimeout] once the AI command finishes capturing.
  /// Changing this value only affects the *next* armed timer (see
  /// [_armSilenceTimer]); it never disrupts a timer already ticking
  /// with the previous duration. This is purely additive: any caller
  /// that never touches this field observes byte-for-byte identical
  /// behavior to before this field became mutable.
  Duration silenceTimeout;

  VoiceState _state = VoiceState.idle;
  String _partialText = '';
  String _statusMessage = '';
  Timer? _silenceTimer;
  Timer? _errorResetTimer;
  bool _cancelled = false;
  bool _disposed = false;

  VoiceState get state => _state;
  String get partialText => _partialText;
  String get statusMessage => _statusMessage;
  bool get isActive =>
      _state == VoiceState.listening || _state == VoiceState.initializing;

  /// Committed-final callback: text the session finalized.
  void Function(String text)? onFinalText;

  /// Partial callback for progressive display.
  void Function(String text)? onPartialText;

  /// Called when session fully ends (any reason).
  VoidCallback? onSessionEnd;

  /// Forward the desired output script mode to the provider.
  void setScriptMode(ScriptMode mode) {
    try {
      _provider.setScriptMode(mode);
    } catch (_) {}
  }

  /// Forward the desired mic mode (transcribe/translate/auto-mix).
  void setMicMode(MicMode mode) {
    try {
      _provider.setMicMode(mode);
    } catch (_) {}
  }

  /// Forward the desired Translate mode target language.
  void setTranslateTarget(LanguagePack target) {
    try {
      _provider.setTranslateTarget(target);
    } catch (_) {}
  }

  /// Whether the active provider performs speech -> English translation
  /// server-side (see [SpeechProvider.hasNativeTranslateMode]).
  bool get hasNativeTranslateMode {
    try {
      return _provider.hasNativeTranslateMode;
    } catch (_) {
      return false;
    }
  }

  Future<void> startSession(LanguagePack pack) async {
    if (_state != VoiceState.idle && _state != VoiceState.error) return;
    _cancelled = false;
    _partialText = '';
    _setState(VoiceState.initializing, 'Initializing…');

    if (!pack.voiceAvailable) {
      _setState(
        VoiceState.error,
        'Voice not available for ${pack.englishName} yet',
      );
      _scheduleErrorReset();
      return;
    }

    bool ok;
    try {
      ok = await _provider.initialize(pack);
    } catch (_) {
      ok = false;
    }
    if (_cancelled) {
      _finishSession();
      return;
    }
    if (!ok) {
      _setState(VoiceState.error, 'Voice service unavailable');
      _scheduleErrorReset();
      return;
    }

    _setState(VoiceState.listening, 'Listening…');
    _armSilenceTimer();
    _provider.start(_handleResult);
  }

  void _handleResult(VoiceResult r) {
    // Flush tail: a final utterance that arrives while the session is
    // stopping (server finalizing buffered audio) must never be lost.
    if (_state == VoiceState.stopping &&
        r.isFinal &&
        r.text.trim().isNotEmpty) {
      onFinalText?.call(r.text);
      _partialText = ''; // consumed - prevents double-commit in stopSession
      return;
    }
    if (_state != VoiceState.listening || _cancelled) return;
    _armSilenceTimer(); // speech activity resets silence window
    _partialText = r.text;
    onPartialText?.call(r.text);
    if (r.isFinal) {
      onFinalText?.call(r.text);
      _partialText = '';
      _statusMessage = 'Listening…';
      // A final segment is not the end of the user's session. Restart the
      // provider and keep listening; the inactivity guard below ends the
      // session only after a genuinely quiet period or manual stop.
      _provider.start(_handleResult);
    }
    notifyListeners();
  }

  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(silenceTimeout, () {
      // Silence auto-stop: commit any partial text and end cleanly.
      if (_state == VoiceState.listening) {
        stopSession(reason: 'auto');
      }
    });
  }

  /// Manual or automatic clean stop. Never surfaces internal errors.
  Future<void> stopSession({String reason = 'manual'}) async {
    if (_state == VoiceState.idle || _state == VoiceState.stopping) return;
    _cancelled = true;
    _setState(VoiceState.stopping, 'Stopping…');
    _silenceTimer?.cancel();
    try {
      await _provider.stop();
    } catch (_) {
      // Intentional cancellation is not a user-facing error.
    }
    // Commit remaining partial text so nothing the user said is lost.
    if (_partialText.trim().isNotEmpty) {
      onFinalText?.call(_partialText);
    }
    _finishSession();
  }

  /// Cancels voice immediately for a keyboard key interaction. It commits the
  /// latest partial transcript synchronously, then stops the provider
  /// asynchronously, so the key tap is not blocked by network finalization.
  void cancelForKeyPress() {
    if (!isActive) return;
    _cancelled = true;
    _silenceTimer?.cancel();
    final pending = _partialText.trim();
    _partialText = '';
    if (pending.isNotEmpty) onFinalText?.call(pending);
    _finishSession();
    unawaited(_provider.stop().catchError((_) {}));
  }

  void _finishSession() {
    _partialText = '';
    _silenceTimer?.cancel();
    _setState(VoiceState.idle, '');
    onSessionEnd?.call();
  }

  void _scheduleErrorReset() {
    _errorResetTimer?.cancel();
    _errorResetTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      if (_state == VoiceState.error) {
        _setState(VoiceState.idle, '');
        onSessionEnd?.call();
      }
    });
  }

  void _setState(VoiceState s, String msg) {
    if (_disposed) return;
    _state = s;
    _statusMessage = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _silenceTimer?.cancel();
    _errorResetTimer?.cancel();
    _provider.stop();
    super.dispose();
  }
}
