/// Stateless wake-word detection for the optional AI Web Assistant
/// feature. Deliberately isolated with zero dependencies so it can be
/// unit-tested trivially and adds no measurable overhead to the voice
/// pipeline when checked on every finalized utterance.
library;

/// Result of attempting to detect the assistant's wake word inside a
/// finalized voice-transcription utterance.
class WakeWordExtraction {
  /// True if the wake word was found anywhere in the utterance.
  final bool matched;

  /// The utterance with the wake word removed and leftover leading
  /// punctuation cleaned up. Only meaningful when [matched] is true;
  /// empty when the wake word was said alone with no command text
  /// around it (e.g. just "Bhasha").
  final String query;

  const WakeWordExtraction({required this.matched, required this.query});

  static const none = WakeWordExtraction(matched: false, query: '');
}

/// Detects a configurable wake word (default "Bhasha") inside recognized
/// speech text and extracts the clean command query around it.
///
/// Matching is token-based rather than regex-lookbehind based, so it is
/// simple, dependency-free and trivially testable:
///  - Case-insensitive.
///  - Ignores leading/trailing punctuation on each spoken word (a
///    recognizer may emit "Bhasha," or "bhasha?").
///  - Supports multi-word assistant names (tokens must appear
///    contiguously, in order).
///  - Matches the wake word anywhere in the utterance (start, middle or
///    end) - not only as a strict prefix - since users may phrase it as
///    "Bhasha, what is..." or "...ok Bhasha...".
class WakeWordDetector {
  const WakeWordDetector._();

  static String _normalize(String token) =>
      token.toLowerCase().replaceAll(RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'), '');

  static List<String> _tokenize(String text) =>
      text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  /// Detects [wakeWord] inside [text] and, if found, returns the
  /// remaining text (wake word removed) as the clean query. Returns
  /// [WakeWordExtraction.none] when the wake word is not present or is
  /// itself blank/invalid.
  static WakeWordExtraction detect(String text, String wakeWord) {
    final wakeTokensRaw = _tokenize(wakeWord);
    if (wakeTokensRaw.isEmpty) return WakeWordExtraction.none;
    final wakeTokens = wakeTokensRaw.map(_normalize).toList();
    if (wakeTokens.any((t) => t.isEmpty)) return WakeWordExtraction.none;

    final tokens = _tokenize(text);
    if (tokens.isEmpty) return WakeWordExtraction.none;

    for (var i = 0; i + wakeTokens.length <= tokens.length; i++) {
      var isMatch = true;
      for (var j = 0; j < wakeTokens.length; j++) {
        if (_normalize(tokens[i + j]) != wakeTokens[j]) {
          isMatch = false;
          break;
        }
      }
      if (!isMatch) continue;

      final remaining = <String>[
        ...tokens.sublist(0, i),
        ...tokens.sublist(i + wakeTokens.length),
      ];
      var query = remaining.join(' ').trim();
      // Strip a leftover leading connector/punctuation, e.g. the comma
      // after "Bhasha," or a stray leading "please".
      query = query.replaceAll(RegExp(r'^[,:;.\-–—\s]+'), '').trim();
      return WakeWordExtraction(matched: true, query: query);
    }
    return WakeWordExtraction.none;
  }
}
