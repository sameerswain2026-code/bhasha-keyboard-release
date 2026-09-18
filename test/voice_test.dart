/// Gate C tests: voice lifecycle - start/stop, partial results,
/// silence auto-stop, continuous speech, cancellation, error states.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bhasha_keyboard/data/languages.dart';
import 'package:bhasha_keyboard/engine/voice_engine.dart';

/// Controllable fake provider for deterministic lifecycle tests.
class FakeSpeechProvider implements SpeechProvider {
  void Function(VoiceResult)? _onResult;
  bool initShouldFail = false;
  int startCount = 0;
  bool stopped = false;

  @override
  Future<bool> initialize(LanguagePack pack) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return !initShouldFail;
  }

  @override
  void start(void Function(VoiceResult) onResult) {
    _onResult = onResult;
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  void setScriptMode(ScriptMode mode) {}

  @override
  void setMicMode(MicMode mode) {}

  @override
  void setTranslateTarget(LanguagePack target) {}

  @override
  bool get hasNativeTranslateMode => false;

  void emitPartial(String text) => _onResult?.call(VoiceResult(text, false));
  void emitFinal(String text) => _onResult?.call(VoiceResult(text, true));
}

void main() {
  final en = LanguageRegistry.byId('en');

  group('Gate C: Voice lifecycle (P0)', () {
    test('idle -> initializing -> listening on start', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      expect(v.state, VoiceState.idle);
      final future = v.startSession(en);
      expect(v.state, VoiceState.initializing);
      await future;
      expect(v.state, VoiceState.listening);
      expect(v.statusMessage, 'Listening…');
      await v.stopSession();
      v.dispose();
    });

    test('partial results are progressive', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      final partials = <String>[];
      v.onPartialText = partials.add;
      await v.startSession(en);
      fake.emitPartial('hello');
      fake.emitPartial('hello how');
      fake.emitPartial('hello how are');
      expect(partials, ['hello', 'hello how', 'hello how are']);
      expect(v.partialText, 'hello how are');
      await v.stopSession();
      v.dispose();
    });

    test('final result commits text and continues session', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      final finals = <String>[];
      v.onFinalText = finals.add;
      await v.startSession(en);
      fake.emitPartial('hello');
      fake.emitFinal('hello world');
      expect(finals, ['hello world']);
      expect(
        v.state,
        VoiceState.listening,
        reason: 'continuous speech keeps session alive',
      );
      expect(fake.startCount, 2, reason: 'stream restarted after final');
      await v.stopSession();
      v.dispose();
    });

    test('manual stop commits pending partial text (never lost)', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      final finals = <String>[];
      v.onFinalText = finals.add;
      await v.startSession(en);
      fake.emitPartial('unfinished sentence');
      await v.stopSession();
      expect(finals, ['unfinished sentence']);
      expect(v.state, VoiceState.idle);
      expect(v.partialText, '');
      v.dispose();
    });

    test('silence auto-stop triggers after timeout', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(
        provider: fake,
        silenceTimeout: const Duration(milliseconds: 100),
      );
      var sessionEnded = false;
      v.onSessionEnd = () => sessionEnded = true;
      await v.startSession(en);
      expect(v.state, VoiceState.listening);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(v.state, VoiceState.idle, reason: 'auto-stopped on silence');
      expect(sessionEnded, isTrue);
      v.dispose();
    });

    test('speech activity resets silence timer', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(
        provider: fake,
        silenceTimeout: const Duration(milliseconds: 150),
      );
      await v.startSession(en);
      // Keep emitting activity every 80ms - session must stay alive.
      for (int i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        fake.emitPartial('word $i');
        expect(v.state, VoiceState.listening);
      }
      await v.stopSession();
      v.dispose();
    });

    test('cancellation is clean - no internal errors exposed', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      await v.startSession(en);
      await v.stopSession(reason: 'keypress');
      expect(v.state, VoiceState.idle);
      expect(v.statusMessage, '');
      expect(v.statusMessage.toLowerCase(), isNot(contains('cancel')));
      expect(v.statusMessage.toLowerCase(), isNot(contains('coroutine')));
      expect(v.statusMessage.toLowerCase(), isNot(contains('exception')));
      v.dispose();
    });

    test(
      'keypress cancellation is immediate and preserves pending voice text',
      () async {
        final fake = FakeSpeechProvider();
        final v = VoiceEngine(provider: fake);
        final finals = <String>[];
        v.onFinalText = finals.add;
        await v.startSession(en);
        fake.emitPartial('unfinished keypress text');

        v.cancelForKeyPress();

        expect(v.state, VoiceState.idle);
        expect(v.partialText, isEmpty);
        expect(finals, ['unfinished keypress text']);
        expect(fake.stopped, isTrue);
        v.dispose();
      },
    );

    test(
      'init failure produces actionable error then recovers to idle',
      () async {
        final fake = FakeSpeechProvider()..initShouldFail = true;
        final v = VoiceEngine(provider: fake);
        await v.startSession(en);
        expect(v.state, VoiceState.error);
        expect(v.statusMessage, 'Voice service unavailable');
        v.dispose();
      },
    );

    test('voice-unavailable language gives meaningful state', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      // All 22 shipped languages now have Sarvam voice; use a synthetic
      // pack to keep the engine's unavailable-path covered.
      const noVoice = LanguagePack(
        id: 'zz',
        englishName: 'TestLang',
        nativeName: 'TestLang',
        locale: 'zz-ZZ',
        family: ScriptFamily.latin,
        voiceAvailable: false,
      );
      await v.startSession(noVoice);
      expect(v.state, VoiceState.error);
      expect(v.statusMessage, contains('TestLang'));
      v.dispose();
    });

    test('double start is ignored while active (never stuck)', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      await v.startSession(en);
      final firstStartCount = fake.startCount;
      await v.startSession(en); // ignored
      expect(fake.startCount, firstStartCount);
      await v.stopSession();
      expect(v.state, VoiceState.idle);
      // Can start again after stop.
      await v.startSession(en);
      expect(v.state, VoiceState.listening);
      await v.stopSession();
      v.dispose();
    });

    test('results arriving after stop are ignored', () async {
      final fake = FakeSpeechProvider();
      final v = VoiceEngine(provider: fake);
      final finals = <String>[];
      v.onFinalText = finals.add;
      await v.startSession(en);
      await v.stopSession();
      fake.emitFinal('late result');
      expect(finals, isEmpty);
      v.dispose();
    });
  });

  group('Simulated provider (web preview)', () {
    test('emits progressive partials ending in a final', () async {
      final p = SimulatedSpeechProvider();
      await p.initialize(en);
      final results = <VoiceResult>[];
      final done = Completer<void>();
      p.start((r) {
        results.add(r);
        if (r.isFinal) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 10));
      await p.stop();
      expect(results.length, greaterThan(1));
      expect(results.last.isFinal, isTrue);
      for (int i = 1; i < results.length; i++) {
        expect(
          results[i].text.length,
          greaterThanOrEqualTo(results[i - 1].text.length),
          reason: 'partials grow progressively',
        );
      }
    });

    test('supports language-specific phrases', () async {
      final p = SimulatedSpeechProvider();
      final hi = LanguageRegistry.byId('hi');
      await p.initialize(hi);
      final results = <VoiceResult>[];
      final done = Completer<void>();
      p.start((r) {
        results.add(r);
        if (r.isFinal) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 10));
      await p.stop();
      expect(
        results.last.text.runes.any((r) => r >= 0x0900 && r <= 0x097F),
        isTrue,
        reason: 'Hindi voice emits Devanagari',
      );
    });
  });
}
