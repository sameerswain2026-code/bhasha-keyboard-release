/// Sarvam text translation client used by the keyboard's Translate mode.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/languages.dart';
import 'sarvam_keys.dart';

class SarvamTranslationService {
  SarvamTranslationService({SarvamKeyPool? keyPool, http.Client? client})
    : _pool = keyPool ?? SarvamKeyPool.production(),
      _client = client ?? http.Client();

  static final Uri _endpoint = Uri.parse('https://api.sarvam.ai/translate');
  // Keep the keyboard responsive: a slow translation request should quickly
  // fall back to the local/secondary path instead of holding the finalized
  // voice segment for eight seconds.
  static const Duration _timeout = Duration(seconds: 3);
  final SarvamKeyPool _pool;
  final http.Client _client;

  bool get isConfigured => _pool.hasUsableKey;

  /// Translates a finalized speech segment with Sarvam-Translate:v1.
  /// Returns null on an unavailable service so the caller can retain the
  /// original text rather than inserting a misleading translation.
  Future<String?> translate(
    String input, {
    required LanguagePack source,
    required LanguagePack target,
    required ScriptMode outputStyle,
  }) async {
    final text = input.trim();
    if (text.isEmpty || source.id == target.id) return text;
    if (!isConfigured) return null;

    final payload = <String, dynamic>{
      'input': text,
      'source_language_code': source.translationCode,
      'target_language_code': target.translationCode,
      'model': 'sarvam-translate:v1',
    };
    // Sarvam Translate v1 returns the target language in its native form.
    // `output_script` is not supported by this endpoint; script styling is
    // handled by the caller after translation.

    for (var attempt = 0; attempt < _pool.length; attempt++) {
      final key = _pool.current;
      try {
        final response = await _client
            .post(
              _endpoint,
              headers: {
                'api-subscription-key': key,
                'content-type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(_timeout);
        final decoded = jsonDecode(response.body);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            decoded is Map) {
          final result = (decoded['translated_text'] as String?)?.trim();
          if (result != null && result.isNotEmpty) {
            _pool.markHealthy(key);
            return result;
          }
        }
        if (response.statusCode == 401 ||
            response.statusCode == 402 ||
            response.statusCode == 403 ||
            response.statusCode == 429) {
          _pool.markFailed(key);
          continue;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void dispose() => _client.close();
}
