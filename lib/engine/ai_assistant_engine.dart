/// AI Web Assistant - optional middleware inserted after transcription.
///
/// This is an additive, backward-compatible feature: when disabled (the
/// default), [KeyboardController] never even constructs a request into
/// this engine's search path, so keyboard behavior is byte-for-byte
/// identical to before this feature existed.
///
/// When enabled and a finalized voice utterance contains the configured
/// wake word (default "Bhasha"), the spoken command text is NOT inserted
/// into the active input field. Instead:
///   1. The wake word is stripped, leaving only the clean query.
///   2. AI Router (Gemini): the clean query is sent to [GeminiService]
///      first, which decides whether it can answer directly from its
///      own knowledge or needs live web results.
///      - If it can answer directly, that answer is inserted and
///        Tavily is never called.
///      - If live info is needed, the clean query (never the raw
///        transcript, never the wake word) is sent to the existing
///        [TavilySearchService] exactly as before this feature
///        existed, and the raw result is sent back to Gemini to be
///        summarized into a natural-language answer.
///   3. The final formatted answer is inserted into the active input
///      field in place of the spoken command.
///
/// Gemini is purely an additional reasoning layer in front of the
/// existing Tavily pipeline - it never replaces or modifies
/// [TavilySearchService], [TavilyKeyPool] or [WakeWordDetector]. If
/// Gemini is unavailable at any step (network failure, invalid/expired
/// key, quota exceeded, malformed response, timeout), this engine
/// transparently falls back to the exact pre-Gemini behavior: Tavily is
/// queried with the original clean query and the plain
/// title/summary/url formatting is used - so a Gemini outage never
/// breaks the assistant.
///
/// Errors at any stage (empty query, network failure, no results) are
/// handled gracefully: a short, friendly message is inserted instead of
/// throwing or leaving the keyboard in a broken state.
library;

import 'wake_word_detector.dart';
import 'tavily_search_service.dart';
import 'gemini_service.dart';

/// Outcome of feeding a finalized voice utterance through the assistant
/// middleware.
enum AiAssistantOutcome {
  /// Wake word not present (or assistant disabled): caller should insert
  /// the original text exactly as before - no behavior change.
  passthrough,

  /// Wake word matched: caller must NOT insert the original spoken text.
  /// The assistant is (asynchronously) resolving a result that will be
  /// delivered via the result callback instead.
  handledAsCommand,
}

class AiAssistantEngine {
  AiAssistantEngine({
    TavilySearchService? searchService,
    GeminiService? geminiService,
  }) : _search = searchService ?? TavilySearchService(),
       _gemini = geminiService ?? GeminiService();

  final TavilySearchService _search;
  final GeminiService _gemini;

  /// Master switch. Defaults to false (feature is opt-in) - callers
  /// (KeyboardController) must check this before doing ANY of the wake
  /// word/Tavily work, so a disabled assistant costs nothing.
  bool enabled = false;

  /// Configurable wake word / assistant name. Defaults to "Bhasha".
  String assistantName = 'Bhasha';

  /// Lightweight, side-effect-free peek: true if [utterance] contains
  /// the configured wake word. Reuses the exact same [WakeWordDetector]
  /// logic [process] itself uses internally - no detection logic is
  /// duplicated anywhere else. Intended for callers (KeyboardController)
  /// that need to decide *before* committing to [process] whether a
  /// multi-chunk command should start being buffered (see
  /// AiCommandCapture) - does not require [enabled] to be true so the
  /// caller controls that gate itself, matching [process]'s own
  /// behavior of never doing wake-word work when disabled.
  bool matchesWakeWord(String utterance) =>
      WakeWordDetector.detect(utterance, assistantName).matched;

  /// Processes a finalized voice utterance.
  ///
  /// - If disabled or no wake word is found: returns
  ///   [AiAssistantOutcome.passthrough] synchronously and the caller
  ///   proceeds exactly as it did before this feature existed (insert
  ///   the text as normal speech).
  /// - If the wake word is found: returns
  ///   [AiAssistantOutcome.handledAsCommand] synchronously (so the
  ///   caller can immediately suppress inserting the raw command text),
  ///   and asynchronously invokes [onResult] with the formatted text to
  ///   insert once the Tavily lookup completes (success or friendly
  ///   error message - never a thrown exception).
  AiAssistantOutcome process(
    String utterance,
    void Function(String formattedInsertText) onResult,
  ) {
    if (!enabled) return AiAssistantOutcome.passthrough;

    final extraction = WakeWordDetector.detect(utterance, assistantName);
    if (!extraction.matched) return AiAssistantOutcome.passthrough;

    // Wake word detected: never insert the spoken command text. Resolve
    // the clean query and run the search asynchronously.
    _runQuery(extraction.query, onResult);
    return AiAssistantOutcome.handledAsCommand;
  }

  Future<void> _runQuery(String query, void Function(String) onResult) async {
    if (query.trim().isEmpty) {
      onResult("Hi, I'm $assistantName. What would you like me to search for?");
      return;
    }

    // AI Router (Gemini) step: ask Gemini first whether it can answer
    // directly or needs live web search. Any Gemini failure here
    // (network, invalid key, timeout, malformed response) falls
    // through to the exact pre-Gemini Tavily-only behavior below -
    // Gemini is purely additive and never blocks the assistant.
    try {
      final decision = await _gemini.decide(query, assistantName);
      if (!decision.needsSearch) {
        if (decision.answer.isNotEmpty) {
          onResult(decision.answer);
          return;
        }
        // Gemini said no search needed but gave no answer either -
        // fall through to Tavily rather than inserting nothing.
      } else {
        await _searchThenSummarize(decision.searchQuery, query, onResult);
        return;
      }
    } catch (_) {
      // Gemini unavailable - fall through to the original Tavily-only
      // pipeline exactly as it behaved before this feature existed.
    }

    await _searchOnly(query, onResult);
  }

  /// Optional Tavily step, followed by sending the raw result back to
  /// Gemini for natural-language summarization/formatting. Falls back
  /// to the plain title+summary+url formatting if Gemini's summarize
  /// step fails for any reason.
  Future<void> _searchThenSummarize(
    String searchQuery,
    String originalQuery,
    void Function(String) onResult,
  ) async {
    TavilySearchResult? result;
    try {
      result = await _search.search(searchQuery);
    } catch (_) {
      onResult(
        "$assistantName couldn't find an answer for \"$originalQuery\".",
      );
      return;
    }
    if (result == null) {
      onResult(
        "$assistantName couldn't find an answer for \"$originalQuery\".",
      );
      return;
    }
    try {
      final summarized = await _gemini.summarize(
        originalQuery,
        result,
        assistantName,
      );
      onResult(summarized);
    } catch (_) {
      // Gemini summarization failed - fall back to the original plain
      // formatting rather than dropping the (successful) search result.
      onResult(_format(result, originalQuery));
    }
  }

  /// Pre-Gemini fallback path: identical to this engine's original
  /// Tavily-only behavior, used whenever Gemini is unavailable.
  Future<void> _searchOnly(String query, void Function(String) onResult) async {
    try {
      final result = await _search.search(query);
      onResult(_format(result, query));
    } catch (_) {
      // Never let a search failure surface as a crash or broken input -
      // graceful, user-visible fallback instead.
      onResult("$assistantName couldn't find an answer for \"$query\".");
    }
  }

  String _format(TavilySearchResult? result, String query) {
    if (result == null) {
      return "$assistantName couldn't find an answer for \"$query\".";
    }
    final buffer = StringBuffer()
      ..writeln(result.title)
      ..writeln(result.summary);
    if (result.url.isNotEmpty) buffer.write(result.url);
    return buffer.toString().trim();
  }

  void dispose() {
    _search.dispose();
    _gemini.dispose();
  }
}
