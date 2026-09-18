/// Buffers a multi-chunk AI voice command after wake-word detection
/// until the user stops speaking (mic session ends) or a configurable
/// inactivity timeout elapses - then hands the FULL buffered utterance
/// to [AiAssistantEngine] exactly once, instead of reacting to only the
/// first finalized speech chunk.
///
/// Why this exists: a real streaming STT session (or the simulated
/// provider) can emit the wake word and the spoken command as separate
/// finalized segments (e.g. "Bhasha" ... pause ... "what is the
/// weather today"), or split one long command across several VAD
/// segments. Without buffering, only the first segment would ever
/// reach the AI Router, silently dropping the rest of the command.
///
/// Deliberately dependency-free and stateless-except-for-its-own-buffer
/// so it is trivial to unit test and adds negligible overhead: starting
/// capture, feeding a chunk and finalizing are all O(1) string-buffer
/// operations plus a single [Timer] reset - no I/O, no serialization,
/// no allocation beyond the buffer itself.
///
/// [KeyboardController] owns the only instance of this class and is
/// responsible for:
///  - Peeking the wake word (via [WakeWordDetector], not duplicated
///    here) on each finalized voice chunk to decide whether to call
///    [start] or [feed].
///  - Calling [finalizeNow] when the mic session ends while capturing
///    is in progress (covers the "mic stops" trigger).
///  - Never calling [feed]/[start] with partial (non-final) transcript
///    text - this class has no concept of partial vs final; it is the
///    caller's job to only ever feed finalized chunks, keeping Gemini
///    calls limited to fully-settled speech as required.
library;

import 'dart:async';

/// Lifecycle of the buffered-command capture.
enum AiCaptureState {
  /// No command is currently being buffered.
  idle,

  /// A wake word was detected and subsequent finalized speech chunks
  /// are being appended to the buffer, with the inactivity timer
  /// resetting on every chunk.
  capturing,
}

/// User-configurable inactivity-timeout presets for AI command capture
/// (Settings -> AI Web Assistant -> "Command Listening Timeout").
/// Deliberately a small fixed set of presets (rather than a free-form
/// duration) so the setting stays simple and there is no way to pick a
/// pathological value that would hurt UX or battery life.
enum AiListeningTimeout {
  /// 3s - reacts quickly; best for short, snappy commands.
  fast(Duration(seconds: 3), 'Fast', '3s · reacts quickly'),

  /// 5s - the default: a balance between responsiveness and giving the
  /// user enough time to phrase a full command.
  balanced(Duration(seconds: 5), 'Balanced', '5s · default'),

  /// 7s - more patient; better for users who pause mid-command.
  patient(Duration(seconds: 7), 'Patient', '7s · allows more pausing'),

  /// 10s - most patient; best for longer, multi-part commands.
  extended(Duration(seconds: 10), 'Extended', '10s · for longer commands');

  const AiListeningTimeout(this.duration, this.label, this.description);

  final Duration duration;
  final String label;
  final String description;

  /// Persistence key stored via SharedPreferences - the enum's [name]
  /// (e.g. "fast", "balanced") rather than the raw second count, so a
  /// future change to the underlying [duration] values doesn't corrupt
  /// previously-saved preferences.
  static AiListeningTimeout fromName(String? name) {
    if (name == null) return AiListeningTimeout.balanced;
    return AiListeningTimeout.values.firstWhere(
      (v) => v.name == name,
      orElse: () => AiListeningTimeout.balanced,
    );
  }
}

class AiCommandCapture {
  AiCommandCapture({this.timeout = const Duration(seconds: 5)});

  /// Inactivity timeout: how long to wait after the last finalized
  /// speech chunk before finalizing the buffered command
  /// automatically. User-configurable at runtime (see
  /// [KeyboardController.setAiListeningTimeout]) - changing this value
  /// takes effect on the *next* armed timer; it never disrupts a
  /// timer that is already ticking with the previous duration, so the
  /// current in-progress capture is never abruptly cut short.
  Duration timeout;

  AiCaptureState _state = AiCaptureState.idle;
  AiCaptureState get state => _state;
  bool get isCapturing => _state == AiCaptureState.capturing;

  final StringBuffer _buffer = StringBuffer();
  Timer? _inactivityTimer;

  /// Called once the buffered command is ready to be processed - either
  /// the mic session ended ([finalizeNow]) or the inactivity timeout
  /// elapsed. Receives the full buffered utterance, still containing
  /// the wake word exactly as first spoken, so callers can pass it
  /// straight into [AiAssistantEngine.process] unchanged.
  void Function(String fullUtterance)? onFinalize;

  /// Called the instant capture starts (the wake-word chunk) - the UI
  /// uses this to show a "Listening…" indicator for the AI command.
  void Function()? onCaptureStart;

  /// Called whenever capture ends for ANY reason - normal finalize
  /// ([finalizeNow] or the inactivity timeout) or [cancel] - always
  /// exactly once per matching [onCaptureStart], so an owner can use
  /// this single symmetric hook for bookkeeping (e.g. restoring a
  /// temporarily-widened mic silence-timeout) without duplicating that
  /// logic at every call site that can end a capture.
  void Function()? onCaptureEnd;

  /// Begins buffering a new command starting with [firstChunk] (the
  /// caller has already confirmed this chunk contains the wake word).
  /// Any previous (stale) buffer content is discarded first.
  void start(String firstChunk) {
    _inactivityTimer?.cancel();
    _buffer.clear();
    _buffer.write(firstChunk);
    _state = AiCaptureState.capturing;
    onCaptureStart?.call();
    _armTimer();
  }

  /// Appends another finalized speech chunk to the in-progress buffer
  /// and resets the inactivity timer, since speech is still ongoing.
  /// No-op if capture isn't active or the chunk is blank.
  void feed(String chunk) {
    if (_state != AiCaptureState.capturing) return;
    if (chunk.trim().isEmpty) return;
    _buffer.write(' ');
    _buffer.write(chunk);
    _armTimer();
  }

  /// Finalizes immediately - used when the mic session stops while a
  /// capture is in progress, so the buffered command isn't left
  /// waiting out the full inactivity timeout unnecessarily. No-op if
  /// nothing is being captured.
  void finalizeNow() {
    if (_state != AiCaptureState.capturing) return;
    _complete();
  }

  /// Cancels capture without finalizing (e.g. the assistant is turned
  /// off mid-capture) - buffered text is discarded, [onFinalize] is
  /// never invoked.
  void cancel() {
    if (_state != AiCaptureState.capturing) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _buffer.clear();
    _state = AiCaptureState.idle;
    onCaptureEnd?.call();
  }

  void _armTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeout, _complete);
  }

  void _complete() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    final text = _buffer.toString().trim();
    _buffer.clear();
    _state = AiCaptureState.idle;
    onCaptureEnd?.call();
    if (text.isNotEmpty) onFinalize?.call(text);
  }

  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }
}
