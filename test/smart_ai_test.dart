import 'package:flutter_test/flutter_test.dart';
import 'package:bhasha_keyboard/engine/ai_command_capture.dart';
import 'package:bhasha_keyboard/engine/wake_word_detector.dart';

void main() {
  group('Smart AI wake word', () {
    test('matches an edited ASCII assistant name with punctuation', () {
      final result = WakeWordDetector.detect(
        'Jarvis, search Google for the weather',
        'Jarvis',
      );
      expect(result.matched, isTrue);
      expect(result.query, 'search Google for the weather');
    });

    test('matches a Unicode assistant name', () {
      final result = WakeWordDetector.detect(
        'नमस्ते सखी, एक पत्र लिखो',
        'सखी',
      );
      expect(result.matched, isTrue);
      expect(result.query, 'नमस्ते एक पत्र लिखो');
    });
  });

  test('AI capture keeps all finalized segments until five seconds idle', () async {
    final capture = AiCommandCapture(timeout: const Duration(milliseconds: 80));
    final finalized = <String>[];
    capture.onFinalize = finalized.add;

    capture.start('Jarvis');
    capture.feed('write a letter');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    capture.feed('to my college');
    expect(finalized, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(finalized, ['Jarvis write a letter to my college']);
    capture.dispose();
  });
}
