/// Translation provider abstraction with an offline phrase dictionary
/// fallback. Real cloud providers can be plugged behind [TranslationProvider].
library;

import 'dart:async';

import '../data/languages.dart';
import 'transliterator.dart';

abstract class TranslationProvider {
  Future<String?> translate(String text, LanguagePack from, LanguagePack to);
}

/// Fast offline detector for selected text using Unicode script ranges.
class TranslationLanguageDetector {
  static LanguagePack detect(String text) {
    final scores = <String, int>{};
    for (final rune in text.runes) {
      final id = _scriptId(rune);
      if (id != null) scores[id] = (scores[id] ?? 0) + 1;
    }
    if (scores.isEmpty) return LanguageRegistry.byId('en');
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return LanguageRegistry.byId(best.key);
  }

  static String? _scriptId(int r) {
    if (r >= 0x0900 && r <= 0x097F) return 'hi';
    if (r >= 0x0980 && r <= 0x09FF) return 'bn';
    if (r >= 0x0A00 && r <= 0x0A7F) return 'pa';
    if (r >= 0x0A80 && r <= 0x0AFF) return 'gu';
    if (r >= 0x0B00 && r <= 0x0B7F) return 'or';
    if (r >= 0x0B80 && r <= 0x0BFF) return 'ta';
    if (r >= 0x0C00 && r <= 0x0C7F) return 'te';
    if (r >= 0x0C80 && r <= 0x0CFF) return 'kn';
    if (r >= 0x0D00 && r <= 0x0D7F) return 'ml';
    if (r >= 0x0600 && r <= 0x06FF) return 'ur';
    if ((r >= 0x0041 && r <= 0x005A) || (r >= 0x0061 && r <= 0x007A)) {
      return 'en';
    }
    return null;
  }
}

/// Offline dictionary provider: common phrases between English and
/// major Indian languages, with transliteration fallback.
class OfflineTranslationProvider implements TranslationProvider {
  static const Map<String, Map<String, String>> _enTo = {
    'hi': {
      'hello': 'नमस्ते',
      'hi': 'नमस्ते',
      'thank you': 'धन्यवाद',
      'thanks': 'धन्यवाद',
      'yes': 'हाँ',
      'no': 'नहीं',
      'good morning': 'सुप्रभात',
      'good night': 'शुभ रात्रि',
      'how are you': 'आप कैसे हैं',
      'i am fine': 'मैं ठीक हूँ',
      'welcome': 'स्वागत है',
      'please': 'कृपया',
      'sorry': 'माफ़ कीजिए',
      'i love you': 'मैं तुमसे प्यार करता हूँ',
      'what is your name': 'आपका नाम क्या है',
      'my name is': 'मेरा नाम है',
      'where are you': 'आप कहाँ हैं',
      'see you tomorrow': 'कल मिलते हैं',
      'happy birthday': 'जन्मदिन मुबारक',
      'congratulations': 'बधाई हो',
      'good': 'अच्छा',
      'water': 'पानी',
      'food': 'खाना',
      'home': 'घर',
      'friend': 'दोस्त',
      'family': 'परिवार',
      'love': 'प्यार',
      'time': 'समय',
      'today': 'आज',
      'tomorrow': 'कल',
    },
    'bn': {
      'hello': 'নমস্কার',
      'thank you': 'ধন্যবাদ',
      'thanks': 'ধন্যবাদ',
      'yes': 'হ্যাঁ',
      'no': 'না',
      'how are you': 'আপনি কেমন আছেন',
      'i am fine': 'আমি ভালো আছি',
      'good morning': 'সুপ্রভাত',
      'welcome': 'স্বাগতম',
      'good': 'ভালো',
      'water': 'জল',
      'food': 'খাবার',
      'home': 'বাড়ি',
      'friend': 'বন্ধু',
      'love': 'ভালোবাসা',
    },
    'ta': {
      'hello': 'வணக்கம்',
      'thank you': 'நன்றி',
      'thanks': 'நன்றி',
      'yes': 'ஆம்',
      'no': 'இல்லை',
      'how are you': 'எப்படி இருக்கிறீர்கள்',
      'i am fine': 'நான் நலமாக இருக்கிறேன்',
      'good morning': 'காலை வணக்கம்',
      'welcome': 'வரவேற்கிறோம்',
      'good': 'நல்லது',
      'water': 'தண்ணீர்',
      'food': 'உணவு',
      'home': 'வீடு',
      'friend': 'நண்பர்',
      'love': 'அன்பு',
    },
    'te': {
      'hello': 'నమస్తే',
      'thank you': 'ధన్యవాదాలు',
      'thanks': 'ధన్యవాదాలు',
      'yes': 'అవును',
      'no': 'కాదు',
      'how are you': 'మీరు ఎలా ఉన్నారు',
      'i am fine': 'నేను బాగున్నాను',
      'good morning': 'శుభోదయం',
      'welcome': 'స్వాగతం',
      'good': 'మంచి',
      'water': 'నీరు',
      'food': 'ఆహారం',
      'home': 'ఇల్లు',
      'friend': 'స్నేహితుడు',
      'love': 'ప్రేమ',
    },
    'mr': {
      'hello': 'नमस्कार',
      'thank you': 'धन्यवाद',
      'yes': 'हो',
      'no': 'नाही',
      'how are you': 'तुम्ही कसे आहात',
      'i am fine': 'मी ठीक आहे',
      'good morning': 'शुभ सकाळ',
      'welcome': 'स्वागत आहे',
      'good': 'चांगले',
      'water': 'पाणी',
      'food': 'जेवण',
      'home': 'घर',
      'friend': 'मित्र',
      'love': 'प्रेम',
    },
    'gu': {
      'hello': 'નમસ્તે',
      'thank you': 'આભાર',
      'yes': 'હા',
      'no': 'ના',
      'how are you': 'તમે કેમ છો',
      'i am fine': 'હું મજામાં છું',
      'good morning': 'સુપ્રભાત',
      'welcome': 'સ્વાગત છે',
      'good': 'સારું',
      'water': 'પાણી',
      'food': 'ભોજન',
      'home': 'ઘર',
      'friend': 'મિત્ર',
      'love': 'પ્રેમ',
    },
    'kn': {
      'hello': 'ನಮಸ್ಕಾರ',
      'thank you': 'ಧನ್ಯವಾದ',
      'yes': 'ಹೌದು',
      'no': 'ಇಲ್ಲ',
      'how are you': 'ನೀವು ಹೇಗಿದ್ದೀರಿ',
      'i am fine': 'ನಾನು ಚೆನ್ನಾಗಿದ್ದೇನೆ',
      'good morning': 'ಶುಭೋದಯ',
      'welcome': 'ಸ್ವಾಗತ',
      'good': 'ಒಳ್ಳೆಯದು',
      'water': 'ನೀರು',
      'food': 'ಊಟ',
      'home': 'ಮನೆ',
      'friend': 'ಸ್ನೇಹಿತ',
      'love': 'ಪ್ರೀತಿ',
    },
    'ml': {
      'hello': 'നമസ്കാരം',
      'thank you': 'നന്ദി',
      'yes': 'അതെ',
      'no': 'അല്ല',
      'how are you': 'സുഖമാണോ',
      'i am fine': 'എനിക്ക് സുഖമാണ്',
      'good morning': 'സുപ്രഭാതം',
      'welcome': 'സ്വാഗതം',
      'good': 'നല്ലത്',
      'water': 'വെള്ളം',
      'food': 'ഭക്ഷണം',
      'home': 'വീട്',
      'friend': 'സുഹൃത്ത്',
      'love': 'സ്നേഹം',
    },
    'pa': {
      'hello': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
      'thank you': 'ਧੰਨਵਾਦ',
      'yes': 'ਹਾਂ',
      'no': 'ਨਹੀਂ',
      'how are you': 'ਤੁਸੀਂ ਕਿਵੇਂ ਹੋ',
      'i am fine': 'ਮੈਂ ਠੀਕ ਹਾਂ',
      'good morning': 'ਸ਼ੁਭ ਸਵੇਰ',
      'welcome': 'ਜੀ ਆਇਆਂ ਨੂੰ',
      'good': 'ਚੰਗਾ',
      'water': 'ਪਾਣੀ',
      'food': 'ਖਾਣਾ',
      'home': 'ਘਰ',
      'friend': 'ਦੋਸਤ',
      'love': 'ਪਿਆਰ',
    },
    'ur': {
      'hello': 'سلام',
      'thank you': 'شکریہ',
      'yes': 'ہاں',
      'no': 'نہیں',
      'how are you': 'آپ کیسے ہیں',
      'i am fine': 'میں ٹھیک ہوں',
      'good morning': 'صبح بخیر',
      'welcome': 'خوش آمدید',
      'good': 'اچھا',
      'water': 'پانی',
      'food': 'کھانا',
      'home': 'گھر',
      'friend': 'دوست',
      'love': 'محبت',
    },
  };

  @override
  Future<String?> translate(
    String text,
    LanguagePack from,
    LanguagePack to,
  ) async {
    // Simulate small async work; never blocks typing (runs off keypath).
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return null;

    if (from.id == 'en' && _enTo.containsKey(to.id)) {
      final dict = _enTo[to.id]!;
      // Exact phrase
      if (dict.containsKey(q)) return dict[q];
      // Word-by-word with dictionary + transliteration fallback
      final words = q.split(RegExp(r'\s+'));
      final out = words
          .map((w) {
            return dict[w] ?? Transliterator.transliterate(w, to);
          })
          .join(' ');
      return out;
    }

    // Reverse: native -> English via inverted dictionary.
    if (to.id == 'en' && _enTo.containsKey(from.id)) {
      final dict = _enTo[from.id]!;
      // First-wins inversion: 'thank you' and 'thanks' both map to the
      // same native word; the primary (first) English phrase must win.
      final inverted = <String, String>{};
      for (final e in dict.entries) {
        inverted.putIfAbsent(e.value, () => e.key);
      }
      if (inverted.containsKey(text.trim())) return inverted[text.trim()];
      final words = text.trim().split(RegExp(r'\s+'));
      final out = words.map((w) => inverted[w] ?? w).join(' ');
      return out;
    }

    // Indic -> Indic: pivot unavailable offline; transliterate as fallback.
    if (!to.isLatin) {
      return Transliterator.transliterate(q, to);
    }
    return null;
  }
}

class TranslationEngine {
  TranslationEngine({TranslationProvider? provider})
    : _provider = provider ?? OfflineTranslationProvider();

  final TranslationProvider _provider;

  Future<String?> translate(String text, LanguagePack from, LanguagePack to) {
    return _provider.translate(text, from, to);
  }
}
