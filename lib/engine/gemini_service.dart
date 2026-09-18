/// Gemini AI reasoning layer for the AI Web Assistant.
///
/// Sits in front of the existing Tavily search integration (see
/// [AiAssistantEngine]) as an additional reasoning step - the "AI
/// Router" in the flow: Speech -> Sarvam STT -> Wake Word -> AI Router
/// (Gemini) -> (Optional Tavily) -> Response Formatter -> Insert.
///
/// Every assistant query is first sent to Gemini via [decide], which
/// decides whether it can answer directly (general knowledge,
/// definitions, math, jokes, translations, etc.) or whether live web
/// results are required (anything involving "today", "current",
/// "latest", news, prices, scores, weather, or other real-time facts).
/// Only when Gemini asks for it does the existing [TavilySearchService]
/// get called by [AiAssistantEngine]; Tavily's raw result is then sent
/// back to Gemini via [summarize] so it can produce a natural-language
/// final answer instead of the plain title+summary+url format.
///
/// This file has zero knowledge of wake words, transcripts, or keyboard
/// state - exactly like [TavilySearchService] - and every failure path
/// (network, timeout, malformed JSON, key exhausted) throws so the
/// caller ([AiAssistantEngine]) can gracefully fall back to the
/// pre-Gemini Tavily-only behavior rather than ever crashing or hanging
/// the keyboard.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_keys.dart';
import 'tavily_search_service.dart';

/// Gemini's decision about how to handle a query - the "AI Router"
/// output.
class GeminiDecision {
  /// True when Gemini needs live web results before it can answer.
  final bool needsSearch;

  /// Gemini's direct answer (only meaningful when [needsSearch] is
  /// false).
  final String answer;

  /// A concise web-search query Gemini suggests (only meaningful when
  /// [needsSearch] is true) - callers should fall back to the original
  /// query when this is blank.
  final String searchQuery;

  const GeminiDecision({
    required this.needsSearch,
    required this.answer,
    required this.searchQuery,
  });
}

/// Thin, defensive Gemini API client (Google Generative Language API).
///
/// Mirrors [TavilySearchService]'s design: a key pool with automatic
/// failover rotation on auth/quota/rate-limit errors, a short client
/// timeout so a slow/unreachable endpoint never noticeably delays
/// typing, and every method throws on failure rather than returning a
/// misleading empty/default value - callers are expected to catch and
/// fall back.
class GeminiService {
  GeminiService({GeminiKeyPool? keyPool, http.Client? client})
    : _pool = keyPool ?? GeminiKeyPool.production(),
      _client = client ?? http.Client();

  static const String _model = 'gemini-3.1-flash-lite';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Kept short so a slow/unreachable Gemini endpoint never noticeably
  /// delays typing - [AiAssistantEngine] falls back to the pre-Gemini
  /// pipeline on timeout rather than waiting indefinitely.
  static const Duration _timeout = Duration(seconds: 6);

  final GeminiKeyPool _pool;
  final http.Client _client;

  /// AI Router step: ask Gemini whether it can answer [query] directly
  /// or needs live web search. Throws on any failure (network,
  /// timeout, malformed response, all keys exhausted) - callers must
  /// catch and fall back, never assume this always succeeds.
  Future<GeminiDecision> decide(String query, String assistantName) async {
    final requestedCount = _requestedItemCount(query);
    final countInstruction = requestedCount == null
        ? 'If the user asks for a list, provide a useful complete list.'
        : 'The user explicitly requested $requestedCount items. Preserve that '
              'count when feasible; do not return only one example. Number every '
              'item clearly. For copyrighted movie, song, or book dialogue, '
              'provide brief summaries or short excerpts instead of long '
              'verbatim passages.';
    final prompt =
        'You are $assistantName, a helpful voice assistant embedded '
        'inside a mobile keyboard app. The user asked: "$query"\n\n'
        '$countInstruction\n\n'
        'Decide whether you can answer this accurately and completely '
        'from your own knowledge right now, or whether it requires '
        'live/current information from the web (news, weather, prices, '
        'scores, "today", "latest", "current", or any other real-time '
        'fact you cannot know for certain without searching).\n\n'
        'Respond with ONLY a JSON object, no other text, matching this '
        'exact shape:\n'
        '{"needs_search": true or false, '
        '"answer": "your direct answer if needs_search is false, else '
        'an empty string", '
        '"search_query": "a short, focused web search query if '
        'needs_search is true, else an empty string"}';

    final decoded = await _generate(prompt, jsonMode: true);
    if (decoded is! Map) {
      throw const FormatException('Gemini: unexpected decide() response');
    }
    final needsSearch = decoded['needs_search'] == true;
    final answer = (decoded['answer'] as String?)?.trim() ?? '';
    final searchQuery = (decoded['search_query'] as String?)?.trim() ?? '';
    return GeminiDecision(
      needsSearch: needsSearch,
      answer: answer,
      searchQuery: searchQuery.isEmpty ? query : searchQuery,
    );
  }

  /// Response Formatter step (only reached when [decide] requested
  /// search): sends the raw Tavily result back to Gemini for
  /// natural-language summarization/formatting. Throws on failure -
  /// callers fall back to the plain title+summary+url formatting used
  /// before Gemini existed.
  Future<String> summarize(
    String query,
    TavilySearchResult result,
    String assistantName,
  ) async {
    final requestedCount = _requestedItemCount(query);
    final countInstruction = requestedCount == null
        ? 'Return the complete useful answer supported by the source.'
        : 'Return exactly $requestedCount clearly numbered items when the '
              'request is a list. Do not collapse the answer to one item. For '
              'copyrighted dialogue, use brief summaries or short excerpts '
              'rather than long verbatim text.';
    final prompt =
        'You are $assistantName, a helpful voice assistant embedded '
        'inside a mobile keyboard app. The user asked: "$query"\n\n'
        '$countInstruction\n\n'
        'Here is a live web search result:\n'
        'Title: ${result.title}\n'
        'Summary: ${result.summary}\n'
        'Source: ${result.url}\n\n'
        "Using only this information, write a short, direct, friendly "
        "answer to the user's question (2-3 sentences maximum, plain "
        'text, no markdown formatting). If useful, mention the source '
        'URL at the end. Respond with ONLY the answer text, nothing '
        'else.';

    final text = await _generateText(prompt);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Gemini: empty summarize() response');
    }
    return trimmed;
  }

  int? _requestedItemCount(String query) {
    final match = RegExp(
      r'(?:^|\s)(\d{1,3})\s*(?:items?|things?|dialogues?|'
      r'dialogs?|examples?|points?|ways?|reasons?|steps?)\b',
      caseSensitive: false,
    ).firstMatch(query);
    final value = int.tryParse(match?.group(1) ?? '');
    return value != null && value >= 2 && value <= 100 ? value : null;
  }

  Future<String> _generateText(String prompt) async {
    final decoded = await _generate(prompt, jsonMode: false);
    if (decoded is String) return decoded;
    throw const FormatException('Gemini: expected plain text response');
  }

  /// Shared request logic for both [decide] and [summarize]. Returns
  /// either a decoded JSON [Map] (jsonMode) or a plain [String] (text
  /// mode). Retries across the key pool on auth/quota/rate-limit errors
  /// only, mirroring [TavilySearchService.search]; any other failure
  /// (network, timeout, malformed body) throws immediately so a stuck
  /// request never adds noticeable latency to typing.
  Future<dynamic> _generate(String prompt, {required bool jsonMode}) async {
    for (var attempt = 0; attempt < _pool.length; attempt++) {
      final key = _pool.current;
      final body = <String, dynamic>{
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          if (jsonMode) 'responseMimeType': 'application/json',
          'maxOutputTokens': 4096,
        },
      };

      final response = await _client
          .post(
            Uri.parse('$_endpoint?key=$key'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        _pool.markHealthy(key);
        final text = _extractText(response.body);
        if (text == null) {
          throw const FormatException('Gemini: no text in response');
        }
        if (!jsonMode) return text;
        return jsonDecode(_stripCodeFence(text));
      }

      // Gemini reports an invalid/expired API key as HTTP 400 with
      // status "INVALID_ARGUMENT" / reason "API_KEY_INVALID" (NOT 401,
      // unlike Tavily/Sarvam) - so the response body's message must be
      // checked too, not just the HTTP status code, or a bad key would
      // never trigger rotation.
      if (GeminiKeyPool.isKeyError(
        httpStatus: response.statusCode,
        message: response.body,
      )) {
        final hasMore = _pool.markFailed(key);
        if (!hasMore) throw Exception('Gemini: all keys exhausted');
        continue; // retry with the newly-rotated key
      }
      // Non-key server error (4xx/5xx etc.) - don't hammer other keys.
      throw Exception('Gemini: HTTP ${response.statusCode}');
    }
    throw Exception('Gemini: no keys available');
  }

  String? _extractText(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final content = candidates.first['content'];
      if (content is! Map) return null;
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) return null;
      final text = parts.first['text'];
      return text is String ? text : null;
    } catch (_) {
      return null;
    }
  }

  /// Gemini occasionally wraps JSON in ```json ... ``` fences even when
  /// responseMimeType is requested - strip them defensively before
  /// decoding.
  String _stripCodeFence(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  void dispose() {
    _client.close();
  }
}
