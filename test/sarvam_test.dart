/// Gate G tests: Sarvam AI key pool rotation/failover + language mapping.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:bhasha_keyboard/data/languages.dart';
import 'package:bhasha_keyboard/engine/sarvam_keys.dart';

void main() {
  group('Gate G: Sarvam key pool failover', () {
    test('production pool is safe when no build-time key is configured', () {
      final pool = SarvamKeyPool.production();
      expect(pool.length, 1);
      expect(pool.healthyCount, 1);
      expect(pool.current, isEmpty);
    });

    test('markFailed rotates to next healthy key', () {
      final pool = SarvamKeyPool(['k1', 'k2', 'k3']);
      expect(pool.current, 'k1');
      final ok = pool.markFailed('k1');
      expect(ok, isTrue);
      expect(pool.current, 'k2');
      expect(pool.healthyCount, 2);
    });

    test('rotation skips already-failed keys', () {
      final pool = SarvamKeyPool(['k1', 'k2', 'k3']);
      pool.markFailed('k2'); // pre-fail middle key
      pool.markFailed('k1');
      expect(pool.current, 'k3', reason: 'k2 is failed, jump to k3');
    });

    test('all keys failed resets pool so future sessions can retry', () {
      final pool = SarvamKeyPool(['k1', 'k2']);
      pool.markFailed('k1');
      final ok = pool.markFailed('k2');
      expect(ok, isFalse, reason: 'no healthy key at this moment');
      expect(pool.healthyCount, 2, reason: 'pool reset for recovery');
      expect(pool.current, 'k1');
    });

    test('markHealthy clears failure mark', () {
      final pool = SarvamKeyPool(['k1', 'k2']);
      pool.markFailed('k1');
      pool.markHealthy('k1');
      expect(pool.healthyCount, 2);
    });

    test('key-error detection: http statuses', () {
      expect(SarvamKeyPool.isKeyError(httpStatus: 401), isTrue);
      expect(SarvamKeyPool.isKeyError(httpStatus: 402), isTrue);
      expect(SarvamKeyPool.isKeyError(httpStatus: 403), isTrue);
      expect(SarvamKeyPool.isKeyError(httpStatus: 429), isTrue);
      expect(SarvamKeyPool.isKeyError(httpStatus: 500), isFalse);
    });

    test('key-error detection: websocket close codes', () {
      expect(SarvamKeyPool.isKeyError(closeCode: 4001), isTrue);
      expect(SarvamKeyPool.isKeyError(closeCode: 4429), isTrue);
      expect(
        SarvamKeyPool.isKeyError(closeCode: 1006),
        isFalse,
        reason: 'network drop is not a key problem',
      );
      expect(SarvamKeyPool.isKeyError(closeCode: 1000), isFalse);
    });

    test('key-error detection: message text', () {
      expect(
        SarvamKeyPool.isKeyError(
          message: 'Invalid or missing authentication credentials',
        ),
        isTrue,
        reason: 'Sarvam 403 body observed in live testing',
      );
      expect(SarvamKeyPool.isKeyError(message: 'invalid api key'), isTrue);
      expect(SarvamKeyPool.isKeyError(message: 'Rate limit exceeded'), isTrue);
      expect(SarvamKeyPool.isKeyError(message: 'Insufficient credits'), isTrue);
      expect(SarvamKeyPool.isKeyError(message: 'quota exhausted'), isTrue);
      expect(SarvamKeyPool.isKeyError(message: 'subscription expired'), isTrue);
      expect(
        SarvamKeyPool.isKeyError(message: 'audio must not be None'),
        isFalse,
      );
    });
  });

  group('Gate G: Sarvam language code mapping', () {
    test('Odia maps to od-IN (Sarvam convention)', () {
      expect(LanguageRegistry.byId('or').sarvamCode, 'od-IN');
    });

    test('all other packs use their BCP-47 locale directly', () {
      for (final p in LanguageRegistry.all) {
        if (p.id == 'or') continue;
        expect(p.sarvamCode, p.locale, reason: 'pack ${p.id}');
      }
    });

    test('every language now has voice available via Sarvam', () {
      for (final p in LanguageRegistry.all) {
        expect(p.voiceAvailable, isTrue, reason: 'pack ${p.id}');
      }
    });
  });
}
