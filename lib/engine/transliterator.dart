/// Transliteration engine: Roman input -> native script output.
/// Generic Brahmic engine works across aligned Indic Unicode blocks
/// (Devanagari, Bengali, Gujarati, Gurmukhi, Odia, Tamil, Telugu,
/// Kannada, Malayalam) using relative offsets. Language packs can
/// override or fold codepoints their script does not assign.
library;

import '../data/languages.dart';

class Transliterator {
  // ---- Relative Brahmic offsets (Devanagari block layout) ----

  /// Consonants: roman token -> relative offset from script base.
  static const Map<String, int> _consonants = {
    'k': 0x15,
    'kh': 0x16,
    'g': 0x17,
    'gh': 0x18,
    'ng': 0x19,
    'ch': 0x1A,
    'c': 0x1A,
    'chh': 0x1B,
    'Ch': 0x1B,
    'j': 0x1C,
    'jh': 0x1D,
    'ny': 0x1E,
    'T': 0x1F,
    'Th': 0x20,
    'D': 0x21,
    'Dh': 0x22,
    'N': 0x23,
    't': 0x24,
    'th': 0x25,
    'd': 0x26,
    'dh': 0x27,
    'n': 0x28,
    'p': 0x2A,
    'ph': 0x2B,
    'f': 0x2B,
    'b': 0x2C,
    'bh': 0x2D,
    'm': 0x2E,
    'y': 0x2F,
    'r': 0x30,
    'l': 0x32,
    'v': 0x35,
    'w': 0x35,
    'sh': 0x36,
    'Sh': 0x37,
    's': 0x38,
    'h': 0x39,
    'L': 0x33,
    'q': 0x15,
    'x': 0x15,
    'z': 0x1C,
  };

  /// Independent vowels: roman -> relative offset.
  static const Map<String, int> _vowelsInd = {
    'a': 0x05,
    'aa': 0x06,
    'A': 0x06,
    'i': 0x07,
    'ii': 0x08,
    'ee': 0x08,
    'I': 0x08,
    'u': 0x09,
    'uu': 0x0A,
    'oo': 0x0A,
    'U': 0x0A,
    'e': 0x0F,
    'ai': 0x10,
    'o': 0x13,
    'au': 0x14,
    'ou': 0x14,
    'RRi': 0x0B,
    'Ri': 0x0B,
  };

  /// Dependent vowel signs (matras): roman -> relative offset.
  /// 'a' is inherent (no matra).
  static const Map<String, int> _matras = {
    'aa': 0x3E,
    'A': 0x3E,
    'i': 0x3F,
    'ii': 0x40,
    'ee': 0x40,
    'I': 0x40,
    'u': 0x41,
    'uu': 0x42,
    'oo': 0x42,
    'U': 0x42,
    'e': 0x47,
    'ai': 0x48,
    'o': 0x4B,
    'au': 0x4C,
    'ou': 0x4C,
    'Ri': 0x43,
    'RRi': 0x43,
  };

  static const int _virama = 0x4D;
  static const int _anusvara = 0x02;
  static const int _visarga = 0x03;
  static const int _candrabindu = 0x01;

  // Longest roman token length used by the tokenizer.
  static const int _maxToken = 3;

  // ---- Urdu / Arabic-script map (simple phonetic) ----
  static const Map<String, String> _arabicMap = {
    'a': 'ا',
    'aa': 'آ',
    'b': 'ب',
    'p': 'پ',
    't': 'ت',
    'T': 'ٹ',
    'j': 'ج',
    'ch': 'چ',
    'h': 'ہ',
    'H': 'ح',
    'kh': 'خ',
    'd': 'د',
    'D': 'ڈ',
    'z': 'ز',
    'r': 'ر',
    'R': 'ڑ',
    's': 'س',
    'sh': 'ش',
    'S': 'ص',
    'zh': 'ژ',
    'gh': 'غ',
    'f': 'ف',
    'q': 'ق',
    'k': 'ک',
    'g': 'گ',
    'l': 'ل',
    'm': 'م',
    'n': 'ن',
    'N': 'ں',
    'v': 'و',
    'w': 'و',
    'o': 'و',
    'u': 'و',
    'y': 'ی',
    'i': 'ی',
    'e': 'ے',
    'ai': 'ے',
    'th': 'تھ',
    'dh': 'دھ',
    'bh': 'بھ',
    'ph': 'پھ',
    'jh': 'جھ',
    'x': 'کس',
    'c': 'چ',
  };

  // ---- Ol Chiki (Santali) simple phonetic map ----
  static const Map<String, String> _olChikiMap = {
    'a': 'ᱟ',
    'aa': 'ᱟ',
    'i': 'ᱤ',
    'u': 'ᱩ',
    'e': 'ᱮ',
    'o': 'ᱳ',
    'k': 'ᱠ',
    'g': 'ᱜ',
    'ng': 'ᱝ',
    'ch': 'ᱪ',
    'c': 'ᱪ',
    'j': 'ᱡ',
    't': 'ᱛ',
    'T': 'ᱴ',
    'd': 'ᱫ',
    'D': 'ᱰ',
    'n': 'ᱱ',
    'N': 'ᱬ',
    'p': 'ᱯ',
    'b': 'ᱵ',
    'm': 'ᱢ',
    'y': 'ᱭ',
    'r': 'ᱨ',
    'l': 'ᱞ',
    'w': 'ᱣ',
    'v': 'ᱣ',
    's': 'ᱥ',
    'h': 'ᱦ',
    'R': 'ᱲ',
    'f': 'ᱯ',
    'z': 'ᱡ',
    'q': 'ᱠ',
    'x': 'ᱠ',
    'sh': 'ᱥ',
  };

  // ---- Meetei Mayek (Manipuri) simple phonetic map ----
  static const Map<String, String> _meeteiMap = {
    'a': 'ꯑ',
    'aa': 'ꯑꯥ',
    'i': 'ꯏ',
    'u': 'ꯎ',
    'e': 'ꯑꯦ',
    'o': 'ꯑꯣ',
    'k': 'ꯀ',
    'kh': 'ꯈ',
    'g': 'ꯒ',
    'gh': 'ꯘ',
    'ng': 'ꯉ',
    'ch': 'ꯆ',
    'c': 'ꯆ',
    'j': 'ꯖ',
    'jh': 'ꯓ',
    't': 'ꯇ',
    'th': 'ꯊ',
    'd': 'ꯗ',
    'dh': 'ꯙ',
    'n': 'ꯅ',
    'p': 'ꯄ',
    'ph': 'ꯐ',
    'f': 'ꯐ',
    'b': 'ꯕ',
    'bh': 'ꯚ',
    'm': 'ꯃ',
    'y': 'ꯌ',
    'r': 'ꯔ',
    'l': 'ꯂ',
    'w': 'ꯋ',
    'v': 'ꯋ',
    's': 'ꯁ',
    'sh': 'ꯁ',
    'h': 'ꯍ',
    'T': 'ꯇ',
    'D': 'ꯗ',
    'N': 'ꯅ',
    'z': 'ꯖ',
    'q': 'ꯀ',
    'x': 'ꯀ',
  };

  /// Transliterate a full roman word into the pack's native script.
  static String transliterate(String roman, LanguagePack pack) {
    if (roman.isEmpty || pack.isLatin) return roman;
    switch (pack.family) {
      case ScriptFamily.latin:
        return roman;
      case ScriptFamily.arabic:
        return _mapSimple(roman, _arabicMap, pack);
      case ScriptFamily.olChiki:
        return _mapSimple(roman, _olChikiMap, pack);
      case ScriptFamily.meeteiMayek:
        return _mapSimple(roman, _meeteiMap, pack);
      case ScriptFamily.brahmic:
        return _brahmic(roman, pack);
    }
  }

  static String _mapSimple(
    String roman,
    Map<String, String> map,
    LanguagePack pack,
  ) {
    final out = StringBuffer();
    int i = 0;
    while (i < roman.length) {
      bool matched = false;
      for (int len = _maxToken; len >= 1; len--) {
        if (i + len > roman.length) continue;
        final tok = roman.substring(i, i + len);
        final ov = pack.overrides[tok];
        if (ov != null) {
          out.write(ov);
          i += len;
          matched = true;
          break;
        }
        final exact = map[tok] ?? map[tok.toLowerCase()];
        if (exact != null) {
          out.write(exact);
          i += len;
          matched = true;
          break;
        }
      }
      if (!matched) {
        out.write(roman[i]);
        i++;
      }
    }
    return out.toString();
  }

  static int _fold(int offset, LanguagePack pack) =>
      pack.foldOffsets[offset] ?? offset;

  static String _cp(int base, int offset, LanguagePack pack) =>
      String.fromCharCode(base + _fold(offset, pack));

  static String _brahmic(String roman, LanguagePack pack) {
    final base = pack.scriptBase;
    final out = StringBuffer();
    int i = 0;
    bool prevWasConsonant = false;

    while (i < roman.length) {
      // Pack-level overrides first (longest match).
      String? ovOut;
      int ovLen = 0;
      for (int len = _maxToken; len >= 1; len--) {
        if (i + len > roman.length) continue;
        final tok = roman.substring(i, i + len);
        if (pack.overrides.containsKey(tok)) {
          ovOut = pack.overrides[tok];
          ovLen = len;
          break;
        }
      }
      if (ovOut != null) {
        if (prevWasConsonant) out.write(_cp(base, _virama, pack));
        out.write(ovOut);
        prevWasConsonant = false;
        i += ovLen;
        continue;
      }

      // Special marks.
      if (roman.startsWith('.n', i) || roman.startsWith('M', i)) {
        out.write(_cp(base, _anusvara, pack));
        prevWasConsonant = false;
        i += roman.startsWith('.n', i) ? 2 : 1;
        continue;
      }
      if (roman.startsWith('H', i) &&
          !_consonants.containsKey(_peek(roman, i, 2)) &&
          !_consonants.containsKey(_peek(roman, i, 1))) {
        out.write(_cp(base, _visarga, pack));
        prevWasConsonant = false;
        i += 1;
        continue;
      }
      if (roman.startsWith('.m', i)) {
        out.write(_cp(base, _candrabindu, pack));
        prevWasConsonant = false;
        i += 2;
        continue;
      }

      // Try longest consonant match.
      String? consTok;
      for (int len = _maxToken; len >= 1; len--) {
        if (i + len > roman.length) continue;
        final tok = roman.substring(i, i + len);
        if (_consonants.containsKey(tok)) {
          // Avoid consuming a longer token that ends in a vowel char
          // (consonant tokens never contain vowels except none do).
          consTok = tok;
          break;
        }
      }
      if (consTok != null) {
        if (prevWasConsonant) {
          // Consonant cluster: join with virama.
          out.write(_cp(base, _virama, pack));
        }
        out.write(_cp(base, _consonants[consTok]!, pack));
        prevWasConsonant = true;
        i += consTok.length;
        continue;
      }

      // Try longest vowel match.
      String? vowTok;
      for (int len = _maxToken; len >= 1; len--) {
        if (i + len > roman.length) continue;
        final tok = roman.substring(i, i + len);
        if (_vowelsInd.containsKey(tok)) {
          vowTok = tok;
          break;
        }
      }
      if (vowTok != null) {
        if (prevWasConsonant) {
          // Dependent form (matra). Inherent 'a' produces nothing.
          if (vowTok != 'a') {
            final m = _matras[vowTok];
            if (m != null) out.write(_cp(base, m, pack));
          }
        } else {
          out.write(_cp(base, _vowelsInd[vowTok]!, pack));
        }
        prevWasConsonant = false;
        i += vowTok.length;
        continue;
      }

      // Unknown char: close any open consonant with virama? No -
      // leave inherent 'a' (standard ITRANS behavior keeps inherent).
      prevWasConsonant = false;
      out.write(roman[i]);
      i++;
    }

    return out.toString();
  }

  static String _peek(String s, int i, int len) =>
      (i + 1 + len <= s.length) ? s.substring(i + 1, i + 1 + len) : '';
}
