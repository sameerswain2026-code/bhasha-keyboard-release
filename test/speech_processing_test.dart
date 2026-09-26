import 'package:flutter_test/flutter_test.dart';

import 'package:bhasha_keyboard/data/languages.dart';
import 'package:bhasha_keyboard/engine/speech_processing_engine.dart';

void main() {
  const engine = SpeechProcessingEngine();

  test('smart correction is a no-op when disabled', () {
    final result = engine.process(
      'मैं मैं कल कॉलेज जाऊँगा।',
      language: LanguageRegistry.byId('hi'),
    );
    expect(result, 'मैं मैं कल कॉलेज जाऊँगा।');
  });

  test('removes accidental repeated words but keeps intentional emphasis', () {
    expect(
      engine.process(
        'मैं मैं कल कॉलेज जाऊँगा।',
        language: LanguageRegistry.byId('hi'),
        smartCorrection: true,
      ),
      'मैं कल कॉलेज जाऊँगा।',
    );
    expect(
      engine.process(
        'बहुत बहुत धन्यवाद।',
        language: LanguageRegistry.byId('hi'),
        smartCorrection: true,
      ),
      'बहुत बहुत धन्यवाद।',
    );
  });

  test('replaces Hindi self-correction conservatively', () {
    expect(
      engine.process(
        'कल हम ग्यारह बजे रात को ट्यूशन जाने वाले हैं। नहीं नहीं, कल हम छह बजे ट्यूशन जाने वाले हैं।',
        language: LanguageRegistry.byId('hi'),
        smartCorrection: true,
      ),
      'कल हम छह बजे ट्यूशन जाने वाले हैं।',
    );
  });

  test('replaces English self-correction while preserving sentence prefix', () {
    expect(
      engine.process(
        'I am going to Delhi tomorrow. No, Mumbai tomorrow.',
        language: LanguageRegistry.byId('en'),
        smartCorrection: true,
      ),
      'I am going to Mumbai tomorrow.',
    );
  });
}
