/// Keyboard layout definitions - alpha (QWERTY + native), numeric, symbols.
library;

import '../data/languages.dart';

class LayoutRows {
  final List<List<String>> rows;
  const LayoutRows(this.rows);
}

/// Split a language's native Unicode block into Gboard-like pages. The first
/// page keeps the familiar high-frequency layout; subsequent pages expose the
/// remaining script characters, vowel signs, marks and punctuation.
List<LayoutRows> nativeLayoutPagesFor(LanguagePack pack) {
  final first = kNativeLayouts[pack.id] ?? kDevanagariFallback;
  final seen = <String>{for (final row in first.rows) ...row};
  final chars = <String>[...seen];
  if (pack.family == ScriptFamily.brahmic && pack.scriptBase > 0) {
    for (var offset = 0; offset < 0x80; offset++) {
      final c = String.fromCharCode(pack.scriptBase + offset);
      if (!seen.contains(c)) chars.add(c);
    }
  } else if (pack.family == ScriptFamily.arabic) {
    for (var cp = 0x0600; cp <= 0x06FF; cp++) {
      final c = String.fromCharCode(cp);
      if (!seen.contains(c)) chars.add(c);
    }
  } else if (pack.family == ScriptFamily.olChiki) {
    for (var cp = 0x1C5A; cp <= 0x1C7F; cp++) {
      final c = String.fromCharCode(cp);
      if (!seen.contains(c)) chars.add(c);
    }
  } else if (pack.family == ScriptFamily.meeteiMayek) {
    for (var cp = 0xABC0; cp <= 0xABFF; cp++) {
      final c = String.fromCharCode(cp);
      if (!seen.contains(c)) chars.add(c);
    }
  }
  final pages = <LayoutRows>[];
  for (var i = 0; i < chars.length; i += 27) {
    final end = i + 27 < chars.length ? i + 27 : chars.length;
    final page = chars.sublist(i, end);
    pages.add(LayoutRows([
      page.take(10).toList(),
      page.skip(10).take(9).toList(),
      page.skip(19).take(8).toList(),
    ]));
  }
  return pages.isEmpty ? [first] : pages;
}

/// QWERTY layout for Latin/Roman input.
const LayoutRows kQwerty = LayoutRows([
  ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
  ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
  ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
]);

/// Numeric layer.
const LayoutRows kNumeric = LayoutRows([
  ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
  ['@', '#', '₹', '_', '&', '-', '+', '(', ')'],
  ['*', '"', "'", ':', ';', '!', '?'],
]);

/// Symbols layer.
const LayoutRows kSymbols = LayoutRows([
  ['/', '\\', '<', '>', '_', '&', '@', '#', '~', '`'],
  ['|', '•', '√', 'π', '÷', '×', '±', '^', '=', '%'],
  ['{', '}', '[', ']', '(', ')', '£', '€', '\$', '¢'],
]);

/// Native script layouts (InScript-inspired simplified, 3 rows).
/// Keyed by language pack id. Others fall back to transliteration on QWERTY.
const Map<String, LayoutRows> kNativeLayouts = {
  'hi': LayoutRows([
    ['ौ', 'ै', 'ा', 'ी', 'ू', 'ब', 'ह', 'ग', 'द', 'ज'],
    ['ो', 'े', '्', 'ि', 'ु', 'प', 'र', 'क', 'त', 'च'],
    ['ं', 'म', 'न', 'व', 'ल', 'स', 'य'],
  ]),
  'mr': LayoutRows([
    ['ौ', 'ै', 'ा', 'ी', 'ू', 'ब', 'ह', 'ग', 'द', 'ज'],
    ['ो', 'े', '्', 'ि', 'ु', 'प', 'र', 'क', 'त', 'च'],
    ['ं', 'म', 'न', 'व', 'ल', 'स', 'य'],
  ]),
  'ne': LayoutRows([
    ['ौ', 'ै', 'ा', 'ी', 'ू', 'ब', 'ह', 'ग', 'द', 'ज'],
    ['ो', 'े', '्', 'ि', 'ु', 'प', 'र', 'क', 'त', 'च'],
    ['ं', 'म', 'न', 'व', 'ल', 'स', 'य'],
  ]),
  'sa': LayoutRows([
    ['ौ', 'ै', 'ा', 'ी', 'ू', 'ब', 'ह', 'ग', 'द', 'ज'],
    ['ो', 'े', '्', 'ि', 'ु', 'प', 'र', 'क', 'त', 'च'],
    ['ं', 'म', 'न', 'व', 'ल', 'स', 'य'],
  ]),
  'bn': LayoutRows([
    ['ৌ', 'ৈ', 'া', 'ী', 'ূ', 'ব', 'হ', 'গ', 'দ', 'জ'],
    ['ো', 'ে', '্', 'ি', 'ু', 'প', 'র', 'ক', 'ত', 'চ'],
    ['ং', 'ম', 'ন', 'ল', 'স', 'য়', 'শ'],
  ]),
  'as': LayoutRows([
    ['ৌ', 'ৈ', 'া', 'ী', 'ূ', 'ব', 'হ', 'গ', 'দ', 'জ'],
    ['ো', 'ে', '্', 'ি', 'ু', 'প', 'ৰ', 'ক', 'ত', 'চ'],
    ['ং', 'ম', 'ন', 'ল', 'স', 'য়', 'শ'],
  ]),
  'ta': LayoutRows([
    ['ௌ', 'ை', 'ா', 'ீ', 'ூ', 'ப', 'ஹ', 'க', 'த', 'ஜ'],
    ['ோ', 'ே', '்', 'ி', 'ு', 'ர', 'ற', 'ன', 'ந', 'ச'],
    ['ம', 'ண', 'வ', 'ல', 'ள', 'ஸ', 'ய'],
  ]),
  'te': LayoutRows([
    ['ౌ', 'ై', 'ా', 'ీ', 'ూ', 'బ', 'హ', 'గ', 'ద', 'జ'],
    ['ో', 'ే', '్', 'ి', 'ు', 'ప', 'ర', 'క', 'త', 'చ'],
    ['ం', 'మ', 'న', 'వ', 'ల', 'స', 'య'],
  ]),
  'kn': LayoutRows([
    ['ೌ', 'ೈ', 'ಾ', 'ೀ', 'ೂ', 'ಬ', 'ಹ', 'ಗ', 'ದ', 'ಜ'],
    ['ೋ', 'ೇ', '್', 'ಿ', 'ು', 'ಪ', 'ರ', 'ಕ', 'ತ', 'ಚ'],
    ['ಂ', 'ಮ', 'ನ', 'ವ', 'ಲ', 'ಸ', 'ಯ'],
  ]),
  'ml': LayoutRows([
    ['ൌ', 'ൈ', 'ാ', 'ീ', 'ൂ', 'ബ', 'ഹ', 'ഗ', 'ദ', 'ജ'],
    ['ോ', 'േ', '്', 'ി', 'ു', 'പ', 'ര', 'ക', 'ത', 'ച'],
    ['ം', 'മ', 'ന', 'വ', 'ല', 'സ', 'യ'],
  ]),
  'gu': LayoutRows([
    ['ૌ', 'ૈ', 'ા', 'ી', 'ૂ', 'બ', 'હ', 'ગ', 'દ', 'જ'],
    ['ો', 'ે', '્', 'િ', 'ુ', 'પ', 'ર', 'ક', 'ત', 'ચ'],
    ['ં', 'મ', 'ન', 'વ', 'લ', 'સ', 'ય'],
  ]),
  'pa': LayoutRows([
    ['ੌ', 'ੈ', 'ਾ', 'ੀ', 'ੂ', 'ਬ', 'ਹ', 'ਗ', 'ਦ', 'ਜ'],
    ['ੋ', 'ੇ', '੍', 'ਿ', 'ੁ', 'ਪ', 'ਰ', 'ਕ', 'ਤ', 'ਚ'],
    ['ਂ', 'ਮ', 'ਨ', 'ਵ', 'ਲ', 'ਸ', 'ਯ'],
  ]),
  'or': LayoutRows([
    ['ୌ', 'ୈ', 'ା', 'ୀ', 'ୂ', 'ବ', 'ହ', 'ଗ', 'ଦ', 'ଜ'],
    ['ୋ', 'େ', '୍', 'ି', 'ୁ', 'ପ', 'ର', 'କ', 'ତ', 'ଚ'],
    ['ଂ', 'ମ', 'ନ', 'ଵ', 'ଲ', 'ସ', 'ଯ'],
  ]),
  'ur': LayoutRows([
    ['ط', 'ص', 'ھ', 'د', 'ٹ', 'پ', 'ت', 'ب', 'ج', 'ح'],
    ['م', 'و', 'ر', 'ن', 'ل', 'ہ', 'ا', 'ک', 'ی', 'ے'],
    ['ق', 'ف', 'ز', 'ع', 'س', 'ش', 'گ'],
  ]),
  'ks': LayoutRows([
    ['ط', 'ص', 'ھ', 'د', 'ٹ', 'پ', 'ت', 'ب', 'ج', 'ح'],
    ['م', 'و', 'ر', 'ن', 'ل', 'ہ', 'ا', 'ک', 'ی', 'ے'],
    ['ق', 'ف', 'ز', 'ع', 'س', 'ش', 'گ'],
  ]),
  'sd': LayoutRows([
    ['ط', 'ص', 'ھ', 'د', 'ٽ', 'پ', 'ت', 'ب', 'ج', 'ح'],
    ['م', 'و', 'ر', 'ن', 'ل', 'ه', 'ا', 'ڪ', 'ي', 'ڏ'],
    ['ق', 'ف', 'ز', 'ع', 'س', 'ش', 'گ'],
  ]),
  'sat': LayoutRows([
    ['ᱚ', 'ᱛ', 'ᱜ', 'ᱝ', 'ᱞ', 'ᱟ', 'ᱠ', 'ᱡ', 'ᱢ', 'ᱣ'],
    ['ᱤ', 'ᱥ', 'ᱦ', 'ᱧ', 'ᱨ', 'ᱩ', 'ᱪ', 'ᱫ', 'ᱬ'],
    ['ᱭ', 'ᱮ', 'ᱯ', 'ᱰ', 'ᱱ', 'ᱲ', 'ᱳ'],
  ]),
  'mni': LayoutRows([
    ['ꯀ', 'ꯁ', 'ꯂ', 'ꯃ', 'ꯄ', 'ꯅ', 'ꯆ', 'ꯇ', 'ꯈ', 'ꯉ'],
    ['ꯊ', 'ꯋ', 'ꯌ', 'ꯍ', 'ꯎ', 'ꯏ', 'ꯐ', 'ꯑ', 'ꯒ'],
    ['ꯓ', 'ꯔ', 'ꯕ', 'ꯖ', 'ꯗ', 'ꯘ', 'ꯙ'],
  ]),
};

/// Devanagari-based fallback for languages without a dedicated layout.
const LayoutRows kDevanagariFallback = LayoutRows([
  ['ौ', 'ै', 'ा', 'ी', 'ू', 'ब', 'ह', 'ग', 'द', 'ज'],
  ['ो', 'े', '्', 'ि', 'ु', 'प', 'र', 'क', 'त', 'च'],
  ['ं', 'म', 'न', 'व', 'ल', 'स', 'य'],
]);

LayoutRows layoutFor(LanguagePack pack, ScriptMode mode) {
  if (pack.isLatin || mode == ScriptMode.roman) return kQwerty;
  return kNativeLayouts[pack.id] ?? kDevanagariFallback;
}
