/// Unit tests for [GeminiKeyPool], in particular [GeminiKeyPool.isKeyError]
/// which must correctly detect Gemini's non-standard invalid-key error
/// convention: unlike Tavily/Sarvam (which return HTTP 401/403 for a bad
/// key), Gemini returns **HTTP 400** with `status: "INVALID_ARGUMENT"` and
/// `reason: "API_KEY_INVALID"` in the response body. If [isKeyError] only
/// checked the HTTP status code, a genuinely bad/expired Gemini key would
/// never trigger key rotation.
library;

import 'package:bhasha_keyboard/engine/gemini_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gate G3: GeminiKeyPool.isKeyError', () {
    test('detects the real Gemini invalid-API-key error body (HTTP 400)', () {
      // Actual shape of the error body Gemini returns for a bad key,
      // captured via live curl testing against the real API.
      const body =
          '{"error":{"code":400,"message":"API key not valid. Please pass '
          'a valid API key.","status":"INVALID_ARGUMENT","details":'
          '[{"@type":"type.googleapis.com/google.rpc.ErrorInfo",'
          '"reason":"API_KEY_INVALID","domain":"googleapis.com"}]}}';

      expect(
        GeminiKeyPool.isKeyError(httpStatus: 400, message: body),
        isTrue,
        reason:
            'Gemini signals an invalid key via HTTP 400 + '
            'reason=API_KEY_INVALID in the body, not via HTTP 401/403 - '
            'isKeyError must inspect the message body, not just the '
            'status code.',
      );
    });

    test('HTTP 400 alone (no key-related message) is NOT a key error', () {
      const body =
          '{"error":{"code":400,"message":"Malformed request body",'
          '"status":"INVALID_ARGUMENT"}}';

      expect(
        GeminiKeyPool.isKeyError(httpStatus: 400, message: body),
        isFalse,
        reason:
            'A generic 400 (e.g. bad request shape) must not be treated '
            'as a key error - only key-specific 400s should trigger '
            'rotation.',
      );
    });

    test('HTTP 401/403/429 are always key errors regardless of message', () {
      expect(GeminiKeyPool.isKeyError(httpStatus: 401), isTrue);
      expect(GeminiKeyPool.isKeyError(httpStatus: 403), isTrue);
      expect(GeminiKeyPool.isKeyError(httpStatus: 429), isTrue);
    });

    test('quota/rate-limit style messages are detected as key errors', () {
      expect(
        GeminiKeyPool.isKeyError(
          httpStatus: 429,
          message: '{"error":{"status":"RESOURCE_EXHAUSTED"}}',
        ),
        isTrue,
      );
      expect(
        GeminiKeyPool.isKeyError(message: 'Rate limit exceeded, try again'),
        isTrue,
      );
    });

    test('an unrelated server error (e.g. 500) is not a key error', () {
      expect(
        GeminiKeyPool.isKeyError(
          httpStatus: 500,
          message: '{"error":{"status":"INTERNAL"}}',
        ),
        isFalse,
      );
    });

    test('markFailed rotates away from a bad key and back on reset', () {
      final pool = GeminiKeyPool(['key-a', 'key-b']);
      expect(pool.current, 'key-a');

      final hasMore = pool.markFailed('key-a');
      expect(hasMore, isTrue);
      expect(pool.current, 'key-b');

      // Second key also fails -> pool exhausted -> resets to key-a.
      final hasMoreAfterSecond = pool.markFailed('key-b');
      expect(hasMoreAfterSecond, isFalse);
      expect(pool.current, 'key-a');
      expect(pool.healthyCount, pool.length);
    });

    test('production() is safe without a build-time key', () {
      final pool = GeminiKeyPool.production();
      expect(pool.length, 1);
      expect(pool.current, isEmpty);
    });
  });
}
