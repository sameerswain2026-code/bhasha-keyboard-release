/// Gate A/B tests: core typing, layers, shift/caps, delete, enter,
/// language framework, transliteration, suggestions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bhasha_keyboard/core/keyboard_controller.dart';
import 'package:bhasha_keyboard/data/languages.dart';
import 'package:bhasha_keyboard/data/layouts.dart';
import 'package:bhasha_keyboard/engine/suggestion_engine.dart';
import 'package:bhasha_keyboard/engine/transliterator.dart';
import 'package:bhasha_keyboard/engine/translation_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Gate A: Core typing (P0)', () {
    test('characters are inserted into the editor', () {
      final kb = KeyboardController();
      kb.insertText('h');
      kb.insertText('i');
      expect(kb.editor.text, 'hi');
      kb.dispose();
    });

    test('insert respects cursor position', () {
      final kb = KeyboardController();
      kb.insertText('a');
      kb.insertText('c');
      kb.editor.selection = const TextSelection.collapsed(offset: 1);
      kb.insertText('b');
      expect(kb.editor.text, 'abc');
      kb.dispose();
    });

    test(
      'moving into existing text clears composing anchor and does not duplicate it',
      () {
        final kb = KeyboardController();
        kb.insertText('Hello');
        kb.insertText(' ');
        kb.insertText('Bharat');

        // Move to the start as the text-editing tools do, then type again.
        // The old composing word must not be pasted/replayed at the new cursor.
        kb.moveCursorToStart();
        kb.insertText('Namaste ');

        expect(kb.editor.text, 'Namaste Hello Bharat');
        expect(kb.editor.text, isNot(contains('BharatHello')));
        kb.dispose();
      },
    );

    test('moving one cursor step invalidates the old composing word', () {
      final kb = KeyboardController();
      kb.insertText('Hello');
      kb.moveCursorLeft();
      kb.insertText('X');

      expect(kb.editor.text, 'HellXo');
      kb.dispose();
    });

    test('123 opens numeric layer with working keys', () {
      final kb = KeyboardController();
      kb.setLayer(KeyboardLayer.numeric);
      expect(kb.layer, KeyboardLayer.numeric);
      kb.insertText('4');
      kb.insertText('2');
      expect(kb.editor.text, '42');
      kb.setLayer(KeyboardLayer.alpha);
      expect(kb.layer, KeyboardLayer.alpha);
      kb.dispose();
    });

    test('symbols layer inserts symbols', () {
      final kb = KeyboardController();
      kb.setLayer(KeyboardLayer.symbols);
      kb.insertText('€');
      expect(kb.editor.text, '€');
      kb.dispose();
    });

    test('new input resets panels, layer, and shift to keyboard defaults', () {
      final kb = KeyboardController();
      kb.setLayer(KeyboardLayer.symbols);
      kb.togglePanel(ActivePanel.settings);
      kb.tapShift();
      kb.resetTransientStateForNewInput();
      expect(kb.layer, KeyboardLayer.alpha);
      expect(kb.panel, ActivePanel.none);
      expect(kb.shift, ShiftState.off);
      kb.dispose();
    });

    test('numeric layout data contains digits and rupee', () {
      expect(kNumeric.rows[0], containsAll(['1', '5', '0']));
      expect(kNumeric.rows[1], contains('₹'));
    });

    test('symbols layout contains common slash and shell symbols', () {
      final symbols = kSymbols.rows.expand((row) => row).toSet();
      expect(symbols, containsAll(['/', '\\', '<', '>', '{', '}', '[', ']']));
    });
  });

  group('Gate A: Shift and Caps Lock (P0)', () {
    test('single shift uppercases exactly one letter', () {
      final kb = KeyboardController();
      kb.tapShift();
      expect(kb.shift, ShiftState.single);
      kb.insertText('a');
      kb.insertText('b');
      expect(kb.editor.text, 'Ab');
      expect(kb.shift, ShiftState.off);
      kb.dispose();
    });

    test('double tap enables caps lock; tap again exits', () {
      final kb = KeyboardController();
      kb.tapShift();
      kb.tapShift(); // within 350ms in test -> double
      expect(kb.shift, ShiftState.capsLock);
      kb.insertText('a');
      kb.insertText('b');
      expect(kb.editor.text, 'AB');
      expect(kb.shift, ShiftState.capsLock, reason: 'caps persists');
      kb.tapShift();
      expect(kb.shift, ShiftState.off);
      kb.insertText('c');
      expect(kb.editor.text, 'ABc');
      kb.dispose();
    });
  });

  group('Gate A: Delete (P0)', () {
    test('single delete removes one char', () {
      final kb = KeyboardController();
      kb.insertText('a');
      kb.insertText('b');
      kb.deleteBackward();
      expect(kb.editor.text, 'a');
      kb.dispose();
    });

    test('delete on empty editor is safe', () {
      final kb = KeyboardController();
      kb.deleteBackward();
      expect(kb.editor.text, '');
      kb.dispose();
    });

    test('delete handles emoji surrogate pairs', () {
      final kb = KeyboardController();
      kb.insertContent('😀');
      expect(kb.editor.text, '😀');
      kb.deleteBackward();
      expect(kb.editor.text, '');
      kb.dispose();
    });

    test('delete removes selection', () {
      final kb = KeyboardController();
      kb.insertText('a');
      kb.insertText('b');
      kb.insertText('c');
      kb.editor.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      kb.deleteBackward();
      expect(kb.editor.text, 'c');
      kb.dispose();
    });

    test('swipe-left delete removes the previous word on release', () {
      final kb = KeyboardController();
      for (final c in 'hello world'.split('')) {
        kb.insertText(c);
      }
      kb.startSwipeDelete();
      kb.updateSwipeDelete(-12);
      expect(
        kb.editor.text,
        'hello world',
        reason: 'swipe previews selection without mutating text',
      );
      kb.endSwipeDelete();
      expect(kb.editor.text, 'hello ');
      kb.dispose();
    });

    test('continued swipe-left delete can remove multiple words', () {
      final kb = KeyboardController();
      for (final c in 'hello world again'.split('')) {
        kb.insertText(c);
      }
      kb.startSwipeDelete();
      kb.updateSwipeDelete(-72);
      kb.endSwipeDelete();
      expect(kb.editor.text, '');
      kb.dispose();
    });

    test('continuous delete repeats and stops on release', () async {
      final kb = KeyboardController();
      for (final c in 'hello world'.split('')) {
        kb.insertText(c);
      }
      kb.startContinuousDelete();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      kb.stopContinuousDelete();
      final lenAfterStop = kb.editor.text.length;
      expect(lenAfterStop, lessThan(11));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
        kb.editor.text.length,
        lenAfterStop,
        reason: 'repeat stops immediately on release',
      );
      kb.dispose();
    });
  });

  group('Gate A: Enter (P0)', () {
    test('newline action inserts newline', () {
      final kb = KeyboardController();
      kb.insertText('a');
      final result = kb.pressEnter();
      expect(result, 'newline');
      expect(kb.editor.text, 'a\n');
      kb.dispose();
    });

    test('send/search/done/next dispatch without inserting newline', () {
      final kb = KeyboardController();
      for (final action in [
        EditorAction.send,
        EditorAction.search,
        EditorAction.done,
        EditorAction.next,
      ]) {
        kb.setEditorAction(action);
        kb.insertText('x');
        final before = kb.editor.text;
        final result = kb.pressEnter();
        expect(result, action.name);
        expect(kb.editor.text, before, reason: 'no newline for ${action.name}');
      }
      kb.dispose();
    });
  });

  group('Gate B: 22-language platform', () {
    test('exactly 22 Indian languages + English configured', () {
      expect(kLanguagePacks.length, 23);
      final indian = kLanguagePacks.where((p) => p.id != 'en');
      expect(indian.length, 22);
    });

    test('all packs have required metadata', () {
      for (final p in kLanguagePacks) {
        expect(p.id, isNotEmpty);
        expect(p.englishName, isNotEmpty);
        expect(p.nativeName, isNotEmpty);
        expect(p.locale, contains('-'));
      }
    });

    test('registry lookup and search work', () {
      expect(LanguageRegistry.byId('hi').englishName, 'Hindi');
      expect(LanguageRegistry.byId('nonexistent').id, 'en');
      expect(LanguageRegistry.search('tam').first.id, 'ta');
      expect(LanguageRegistry.search('').length, 23);
    });

    test('language switching commits pending text and persists mode rules', () {
      final kb = KeyboardController();
      expect(kb.language.id, 'en');
      kb.setLanguage(LanguageRegistry.byId('hi'));
      expect(kb.language.id, 'hi');
      // English supports only roman.
      kb.setLanguage(LanguageRegistry.byId('en'));
      expect(kb.scriptMode, ScriptMode.roman);
      kb.dispose();
    });

    test('script mode guarded by language capabilities', () {
      final kb = KeyboardController();
      kb.setLanguage(LanguageRegistry.byId('en'));
      kb.setScriptMode(ScriptMode.native); // not allowed for en
      expect(kb.scriptMode, ScriptMode.roman);
      kb.setLanguage(LanguageRegistry.byId('hi'));
      kb.setScriptMode(ScriptMode.native);
      expect(kb.scriptMode, ScriptMode.native);
      kb.dispose();
    });

    test('every language has a usable layout', () {
      for (final p in kLanguagePacks) {
        final roman = layoutFor(p, ScriptMode.roman);
        expect(roman.rows.length, 3);
        final native = layoutFor(p, ScriptMode.native);
        expect(native.rows.length, 3);
      }
    });
  });

  group('Gate B: Transliteration engine', () {
    final hi = LanguageRegistry.byId('hi');

    test('basic Hindi words', () {
      expect(Transliterator.transliterate('namaste', hi), 'नमस्ते');
      expect(Transliterator.transliterate('ka', hi), 'क');
      expect(Transliterator.transliterate('ki', hi), 'कि');
      expect(Transliterator.transliterate('kii', hi), 'की');
    });

    test('consonant clusters use virama', () {
      // 'kya' -> क + virama + य
      expect(Transliterator.transliterate('kya', hi), 'क्य');
    });

    test('independent vowels', () {
      expect(Transliterator.transliterate('aam', hi), 'आम');
    });

    test('works across script blocks (Bengali, Tamil, Telugu)', () {
      final bn = LanguageRegistry.byId('bn');
      final ta = LanguageRegistry.byId('ta');
      final te = LanguageRegistry.byId('te');
      expect(Transliterator.transliterate('ka', bn), 'ক');
      expect(Transliterator.transliterate('ka', ta), 'க');
      expect(Transliterator.transliterate('ka', te), 'క');
    });

    test('Tamil folds unavailable aspirates', () {
      final ta = LanguageRegistry.byId('ta');
      // 'gha' must not produce an unassigned codepoint - folds to க
      final out = Transliterator.transliterate('gha', ta);
      expect(out, 'க');
    });

    test('Urdu Arabic-script mapping', () {
      final ur = LanguageRegistry.byId('ur');
      final out = Transliterator.transliterate('salam', ur);
      expect(out, isNotEmpty);
      expect(
        out.runes.every((r) => r > 0x0500 || r == 0x20),
        isTrue,
        reason: 'output should be Arabic script',
      );
    });

    test('Santali Ol Chiki and Manipuri Meetei Mayek mapping', () {
      final sat = LanguageRegistry.byId('sat');
      final mni = LanguageRegistry.byId('mni');
      expect(Transliterator.transliterate('ka', sat), 'ᱠᱟ');
      expect(Transliterator.transliterate('ka', mni), 'ꯀꯑ');
    });

    test('latin passthrough', () {
      final en = LanguageRegistry.byId('en');
      expect(Transliterator.transliterate('hello', en), 'hello');
    });

    test('roman typing commits transliterated word on space', () {
      final kb = KeyboardController();
      kb.setLanguage(LanguageRegistry.byId('hi'));
      kb.setScriptMode(ScriptMode.roman);
      for (final c in 'namaste'.split('')) {
        kb.insertText(c);
      }
      expect(kb.editor.text, 'namaste');
      kb.insertText(' ');
      expect(kb.editor.text, 'नमस्ते ');
      kb.dispose();
    });

    test('native mode does not transliterate', () {
      final kb = KeyboardController();
      kb.setLanguage(LanguageRegistry.byId('hi'));
      kb.setScriptMode(ScriptMode.native);
      kb.insertText('क');
      kb.insertText(' ');
      expect(kb.editor.text, 'क ');
      kb.dispose();
    });
  });

  group('Suggestions (P1)', () {
    test('suggestions update as typing occurs', () {
      final kb = KeyboardController();
      kb.insertText('h');
      kb.insertText('e');
      expect(kb.suggestionList, isNotEmpty);
      expect(kb.suggestionList.any((s) => s.startsWith('he')), isTrue);
      kb.dispose();
    });

    test('roman mode surfaces transliteration candidates', () {
      final engine = SuggestionEngine();
      final hi = LanguageRegistry.byId('hi');
      final s = engine.suggest('namaste', hi, ScriptMode.roman);
      expect(s, contains('नमस्ते'));
    });

    test('applying a suggestion replaces the composing word', () {
      final kb = KeyboardController();
      kb.insertText('h');
      kb.insertText('e');
      kb.applySuggestion('hello');
      expect(kb.editor.text, 'hello ');
      kb.dispose();
    });

    test('learned words appear in future suggestions', () {
      final engine = SuggestionEngine();
      final en = LanguageRegistry.byId('en');
      engine.learn('en', 'zephyrix');
      final s = engine.suggest('zeph', en, ScriptMode.roman);
      expect(s, contains('zephyrix'));
    });

    test('suggestion never mutates committed text', () {
      final kb = KeyboardController();
      kb.insertText('d');
      kb.insertText('o');
      kb.insertText('g');
      kb.insertText(' '); // committed
      kb.insertText('c');
      kb.applySuggestion('cat');
      expect(kb.editor.text, 'dog cat ');
      kb.dispose();
    });
  });

  group('Translation engine', () {
    test('en->hi phrase translation', () async {
      final e = TranslationEngine();
      final r = await e.translate(
        'hello',
        LanguageRegistry.byId('en'),
        LanguageRegistry.byId('hi'),
      );
      expect(r, 'नमस्ते');
    });

    test('hi->en reverse translation', () async {
      final e = TranslationEngine();
      final r = await e.translate(
        'धन्यवाद',
        LanguageRegistry.byId('hi'),
        LanguageRegistry.byId('en'),
      );
      expect(r, 'thank you');
    });

    test(
      'unknown words fall back to transliteration for indic target',
      () async {
        final e = TranslationEngine();
        final r = await e.translate(
          'xyzzyq',
          LanguageRegistry.byId('en'),
          LanguageRegistry.byId('hi'),
        );
        expect(r, isNotNull);
        expect(r, isNotEmpty);
      },
    );

    test('empty input returns null', () async {
      final e = TranslationEngine();
      final r = await e.translate(
        '  ',
        LanguageRegistry.byId('en'),
        LanguageRegistry.byId('hi'),
      );
      expect(r, isNull);
    });
  });

  group('Clipboard', () {
    test('history dedupes, most-recent-first, capped at 20', () {
      final kb = KeyboardController();
      for (int i = 0; i < 25; i++) {
        kb.addToClipboardHistory('item$i');
      }
      expect(kb.clipboardHistory.length, 20);
      expect(kb.clipboardHistory.first, 'item24');
      kb.addToClipboardHistory('item24');
      expect(kb.clipboardHistory.where((e) => e == 'item24').length, 1);
      kb.dispose();
    });

    test('paste inserts into editor', () {
      final kb = KeyboardController();
      kb.pasteFromHistory('pasted');
      expect(kb.editor.text, 'pasted');
      kb.dispose();
    });
  });
}
