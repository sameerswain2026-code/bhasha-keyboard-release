/// Tavily web search client used by the optional AI Web Assistant
/// feature (see [AiAssistantEngine]). Isolated in its own file so it has
/// zero footprint when the assistant is disabled - nothing outside this
/// file and [AiAssistantEngine] ever imports it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tavily_keys.dart';

/// A single, clean web-search result: title, short summary and source
/// URL - never the raw Tavily payload (keeps the caller decoupled from
/// the API's shape).
class TavilySearchResult {
  final String title;
  final String summary;
  final String url;
  const TavilySearchResult({
    required this.title,
    required this.summary,
    required this.url,
  });
}

/// Thin, defensive Tavily Search API client.
///
/// - Only ever sends the caller-supplied clean query text - it has no
///   knowledge of wake words, transcripts, or keyboard state.
/// - 5-key pool with automatic failover rotation (mirrors
///   [SarvamSpeechProvider]'s reliability pattern) so a single bad/rate
///   limited key never breaks the feature.
/// - Every failure path (network, timeout, malformed response, all keys
///   exhausted) resolves to `null` rather than throwing - callers must
///   never crash the keyboard because of a web request.
class TavilySearchService {
  TavilySearchService({TavilyKeyPool? keyPool, http.Client? client})
    : _pool = keyPool ?? TavilyKeyPool.production(),
      _client = client ?? http.Client();

  static const String _endpoint = 'https://api.tavily.com/search';
  static const Duration _timeout = Duration(seconds: 8);

  final TavilyKeyPool _pool;
  final http.Client _client;

  /// Runs a single web search for [query] and returns the best result,
  /// or null if nothing useful came back / every attempt failed.
  /// Retries across the key pool on auth/quota/rate-limit errors only;
  /// any other error (network, timeout, parse) returns null immediately
  /// so a stuck request never adds noticeable latency to typing.
  Future<TavilySearchResult?> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    for (var attempt = 0; attempt < _pool.length; attempt++) {
      final key = _pool.current;
      try {
        final response = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $key',
              },
              body: jsonEncode({
                'query': trimmed,
                'search_depth': 'basic',
                'max_results': 1,
                'include_answer': false,
              }),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          _pool.markHealthy(key);
          return _parseResult(response.body);
        }

        if (TavilyKeyPool.isKeyError(httpStatus: response.statusCode)) {
          final hasMore = _pool.markFailed(key);
          if (!hasMore) return null;
          continue; // retry with the newly-rotated key
        }
        // Non-key server error (5xx etc.) - don't hammer other keys.
        return null;
      } catch (_) {
        // Network error / timeout / malformed body: never crash, never
        // retry indefinitely - fail this attempt cleanly.
        return null;
      }
    }
    return null;
  }

  TavilySearchResult? _parseResult(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final results = decoded['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final title = (first['title'] as String?)?.trim() ?? '';
      final content = (first['content'] as String?)?.trim() ?? '';
      final url = (first['url'] as String?)?.trim() ?? '';
      if (title.isEmpty && content.isEmpty) return null;
      return TavilySearchResult(
        title: title.isEmpty ? 'Result' : title,
        summary: _shorten(content),
        url: url,
      );
    } catch (_) {
      return null;
    }
  }

  /// Keeps the inserted summary compact (a short summary, not a raw
  /// content dump) so insertion into the active input field stays fast
  /// and readable.
  String _shorten(String text) {
    const maxLen = 220;
    if (text.length <= maxLen) return text;
    final cut = text.substring(0, maxLen);
    final lastSpace = cut.lastIndexOf(' ');
    final trimmed = lastSpace > 100 ? cut.substring(0, lastSpace) : cut;
    return '$trimmed…';
  }

  void dispose() {
    _client.close();
  }
}
