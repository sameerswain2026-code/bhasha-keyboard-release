/// Suggestion engine: language-aware, offline, non-blocking.
/// Provides prefix completions from local seed dictionaries plus
/// transliteration candidates for Roman-mode Indic languages.
library;

import '../data/languages.dart';
import 'transliterator.dart';

class SuggestionEngine {
  /// User history: learned words per language (session + persisted).
  final Map<String, Set<String>> _learned = {};

  /// Gboard-style next-word prediction: bigram counts per language
  /// (previous word -> next word -> frequency). Learned as the user
  /// types; also seeded with a few common English/Hindi bigrams so
  /// predictions appear immediately for new users.
  final Map<String, Map<String, Map<String, int>>> _bigrams = {};

  static const Map<String, Map<String, List<String>>> _seedBigrams = {
    'en': {
      'how': ['are you', 'is', 'about'],
      'thank': ['you'],
      'good': ['morning', 'night', 'to see you'],
      'see': ['you tomorrow', 'you soon'],
      'i': ['am', 'love', 'will', 'think'],
      'let': ['me know'],
      'nice': ['to meet you'],
    },
    'hi': {
      'आप': ['कैसे हैं', 'कहाँ हैं'],
      'बहुत': ['अच्छा', 'धन्यवाद'],
      'शुभ': ['प्रभात', 'रात्रि'],
    },
  };

  void learnBigram(String languageId, String prevWord, String nextWord) {
    final p = prevWord.trim();
    final n = nextWord.trim();
    if (p.isEmpty || n.isEmpty) return;
    final lang = (_bigrams[languageId] ??= {});
    final nexts = (lang[p.toLowerCase()] ??= {});
    nexts[n] = (nexts[n] ?? 0) + 1;
  }

  /// Top next-word predictions following [prevWord], most-frequent
  /// (learned) first, falling back to seed bigrams.
  List<String> nextWordSuggestions(
    String languageId,
    String prevWord, {
    int limit = 3,
  }) {
    final p = prevWord.trim().toLowerCase();
    if (p.isEmpty) return const [];
    final results = <String>[];
    final seen = <String>{};
    void add(String s) {
      if (s.isNotEmpty && seen.add(s)) results.add(s);
    }

    final learnedNexts = _bigrams[languageId]?[p];
    if (learnedNexts != null) {
      final sorted = learnedNexts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        add(e.key);
        if (results.length >= limit) break;
      }
    }
    if (results.length < limit) {
      final seed = _seedBigrams[languageId]?[p];
      if (seed != null) {
        for (final s in seed) {
          add(s);
          if (results.length >= limit) break;
        }
      }
    }
    return results.take(limit).toList();
  }

  /// Small offline seed dictionaries. Extended by learning.
  static const Map<String, List<String>> _seed = {
    'en': [
      'the',
      'and',
      'you',
      'that',
      'this',
      'with',
      'have',
      'from',
      'they',
      'will',
      'what',
      'about',
      'when',
      'there',
      'their',
      'hello',
      'thanks',
      'thank you',
      'good',
      'great',
      'morning',
      'evening',
      'night',
      'today',
      'tomorrow',
      'yesterday',
      'please',
      'welcome',
      'love',
      'like',
      'time',
      'people',
      'because',
      'India',
      'keyboard',
      'language',
      'message',
      'meeting',
      'family',
      'friend',
      'happy',
      'birthday',
      'congratulations',
      'awesome',
      'nice',
      'okay',
      'yes',
      'no',
      'maybe',
      'sure',
      'sorry',
      'where',
      'which',
      'while',
      'work',
      'world',
      'would',
      'could',
      'should',
      'here',
      'home',
    ],
    'hi': [
      'नमस्ते',
      'धन्यवाद',
      'हाँ',
      'नहीं',
      'आप',
      'मैं',
      'हम',
      'तुम',
      'क्या',
      'कैसे',
      'कहाँ',
      'कब',
      'क्यों',
      'अच्छा',
      'बहुत',
      'प्यार',
      'दोस्त',
      'परिवार',
      'समय',
      'आज',
      'कल',
      'सुबह',
      'शाम',
      'रात',
      'खाना',
      'पानी',
      'घर',
      'काम',
      'भारत',
      'शुभकामनाएं',
      'स्वागत',
    ],
    'bn': [
      'নমস্কার',
      'ধন্যবাদ',
      'হ্যাঁ',
      'না',
      'আপনি',
      'আমি',
      'আমরা',
      'কী',
      'কেমন',
      'কোথায়',
      'ভালো',
      'অনেক',
      'ভালোবাসা',
      'বন্ধু',
      'সময়',
      'আজ',
      'কাল',
      'সকাল',
      'রাত',
      'খাবার',
      'জল',
      'বাড়ি',
    ],
    'ta': [
      'வணக்கம்',
      'நன்றி',
      'ஆம்',
      'இல்லை',
      'நீங்கள்',
      'நான்',
      'நாங்கள்',
      'என்ன',
      'எப்படி',
      'எங்கே',
      'நல்லது',
      'மிகவும்',
      'அன்பு',
      'நண்பர்',
      'நேரம்',
      'இன்று',
      'நாளை',
      'காலை',
      'இரவு',
      'சாப்பாடு',
      'தண்ணீர்',
    ],
    'te': [
      'నమస్తే',
      'ధన్యవాదాలు',
      'అవును',
      'కాదు',
      'మీరు',
      'నేను',
      'మేము',
      'ఏమిటి',
      'ఎలా',
      'ఎక్కడ',
      'మంచి',
      'చాలా',
      'ప్రేమ',
      'స్నేహితుడు',
      'సమయం',
      'ఈరోజు',
      'రేపు',
      'ఉదయం',
      'రాత్రి',
      'భోజనం',
      'నీరు',
    ],
    'mr': [
      'नमस्कार',
      'धन्यवाद',
      'हो',
      'नाही',
      'तुम्ही',
      'मी',
      'आम्ही',
      'काय',
      'कसे',
      'कुठे',
      'चांगले',
      'खूप',
      'प्रेम',
      'मित्र',
      'वेळ',
      'आज',
      'उद्या',
      'सकाळ',
      'रात्र',
      'जेवण',
      'पाणी',
      'घर',
    ],
    'gu': [
      'નમસ્તે',
      'આભાર',
      'હા',
      'ના',
      'તમે',
      'હું',
      'અમે',
      'શું',
      'કેમ',
      'ક્યાં',
      'સારું',
      'ખૂબ',
      'પ્રેમ',
      'મિત્ર',
      'સમય',
      'આજે',
      'કાલે',
      'સવાર',
      'રાત',
      'ભોજન',
      'પાણી',
      'ઘર',
    ],
    'kn': [
      'ನಮಸ್ಕಾರ',
      'ಧನ್ಯವಾದ',
      'ಹೌದು',
      'ಇಲ್ಲ',
      'ನೀವು',
      'ನಾನು',
      'ನಾವು',
      'ಏನು',
      'ಹೇಗೆ',
      'ಎಲ್ಲಿ',
      'ಒಳ್ಳೆಯದು',
      'ತುಂಬಾ',
      'ಪ್ರೀತಿ',
      'ಸ್ನೇಹಿತ',
      'ಸಮಯ',
      'ಇಂದು',
      'ನಾಳೆ',
      'ಬೆಳಗ್ಗೆ',
      'ರಾತ್ರಿ',
      'ಊಟ',
      'ನೀರು',
    ],
    'ml': [
      'നമസ്കാരം',
      'നന്ദി',
      'അതെ',
      'അല്ല',
      'നിങ്ങൾ',
      'ഞാൻ',
      'ഞങ്ങൾ',
      'എന്ത്',
      'എങ്ങനെ',
      'എവിടെ',
      'നല്ലത്',
      'വളരെ',
      'സ്നേഹം',
      'സുഹൃത്ത്',
      'സമയം',
      'ഇന്ന്',
      'നാളെ',
      'രാവിലെ',
      'രാത്രി',
      'ഭക്ഷണം',
      'വെള്ളം',
    ],
    'pa': [
      'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
      'ਧੰਨਵਾਦ',
      'ਹਾਂ',
      'ਨਹੀਂ',
      'ਤੁਸੀਂ',
      'ਮੈਂ',
      'ਅਸੀਂ',
      'ਕੀ',
      'ਕਿਵੇਂ',
      'ਕਿੱਥੇ',
      'ਚੰਗਾ',
      'ਬਹੁਤ',
      'ਪਿਆਰ',
      'ਦੋਸਤ',
      'ਸਮਾਂ',
      'ਅੱਜ',
      'ਕੱਲ੍ਹ',
      'ਸਵੇਰ',
      'ਰਾਤ',
      'ਖਾਣਾ',
      'ਪਾਣੀ',
      'ਘਰ',
    ],
    'ur': [
      'سلام',
      'شکریہ',
      'ہاں',
      'نہیں',
      'آپ',
      'میں',
      'ہم',
      'کیا',
      'کیسے',
      'کہاں',
      'اچھا',
      'بہت',
      'محبت',
      'دوست',
      'وقت',
      'آج',
      'کل',
      'صبح',
      'رات',
      'کھانا',
      'پانی',
      'گھر',
    ],
    'or': [
      'ନମସ୍କାର',
      'ଧନ୍ୟବାଦ',
      'ହଁ',
      'ନା',
      'ଆପଣ',
      'ମୁଁ',
      'ଆମେ',
      'କଣ',
      'କେମିତି',
      'କେଉଁଠି',
      'ଭଲ',
      'ବହୁତ',
      'ପ୍ରେମ',
      'ବନ୍ଧୁ',
    ],
    'as': [
      'নমস্কাৰ',
      'ধন্যবাদ',
      'হয়',
      'নহয়',
      'আপুনি',
      'মই',
      'আমি',
      'কি',
      'কেনেকৈ',
      "ক'ত",
      'ভাল',
      'বহুত',
      'মৰম',
      'বন্ধু',
    ],
  };

  /// Roman-mode phrase mappings for common greetings (per language).
  static const Map<String, Map<String, String>> _romanPhrases = {
    'hi': {
      'namaste': 'नमस्ते',
      'dhanyavad': 'धन्यवाद',
      'shukriya': 'शुक्रिया',
      'kaise': 'कैसे',
      'kya': 'क्या',
      'haan': 'हाँ',
      'nahi': 'नहीं',
      'aap': 'आप',
      'main': 'मैं',
      'accha': 'अच्छा',
      'theek': 'ठीक',
      'pyar': 'प्यार',
      'dost': 'दोस्त',
      'ghar': 'घर',
      'khana': 'खाना',
      'paani': 'पानी',
      'bharat': 'भारत',
      'hindi': 'हिन्दी',
    },
    'bn': {
      'nomoskar': 'নমস্কার',
      'dhonnobad': 'ধন্যবাদ',
      'bhalo': 'ভালো',
      'kemon': 'কেমন',
      'ami': 'আমি',
      'tumi': 'তুমি',
      'bangla': 'বাংলা',
    },
    'ta': {
      'vanakkam': 'வணக்கம்',
      'nandri': 'நன்றி',
      'amma': 'அம்மா',
      'appa': 'அப்பா',
      'tamil': 'தமிழ்',
      'anbu': 'அன்பு',
    },
    'te': {
      'namaste': 'నమస్తే',
      'dhanyavadalu': 'ధన్యవాదాలు',
      'telugu': 'తెలుగు',
      'ela': 'ఎలా',
      'manchi': 'మంచి',
    },
  };

  void learn(String languageId, String word) {
    final w = word.trim();
    if (w.length < 2) return;
    (_learned[languageId] ??= <String>{}).add(w);
  }

  List<String> learnedWords(String languageId) =>
      (_learned[languageId] ?? const <String>{}).toList();

  void restoreLearned(String languageId, List<String> words) {
    (_learned[languageId] ??= <String>{}).addAll(words);
  }

  /// Get suggestions for current composing text.
  /// [mode] determines if roman input should be transliterated.
  List<String> suggest(
    String composing,
    LanguagePack pack,
    ScriptMode mode, {
    int limit = 3,
  }) {
    final text = composing.trim();
    if (text.isEmpty) return const [];

    final results = <String>[];
    final seen = <String>{};

    void add(String s) {
      if (s.isNotEmpty && seen.add(s)) results.add(s);
    }

    final isRomanInput = text.codeUnits.every((c) => c < 0x0250);

    // 1. Transliteration candidate (Roman mode on Indic language).
    if (!pack.isLatin && mode == ScriptMode.roman && isRomanInput) {
      final phrase = _romanPhrases[pack.id]?[text.toLowerCase()];
      if (phrase != null) add(phrase);
      final translit = Transliterator.transliterate(text, pack);
      if (translit != text) add(translit);
      // Prefix phrase matches
      final phrases = _romanPhrases[pack.id];
      if (phrases != null) {
        for (final e in phrases.entries) {
          if (e.key.startsWith(text.toLowerCase()) && e.key != text) {
            add(e.value);
            if (results.length >= limit) break;
          }
        }
      }
    }

    // 2. Learned words (prefix match).
    final learned = _learned[pack.id];
    if (learned != null) {
      for (final w in learned) {
        if (w.toLowerCase().startsWith(text.toLowerCase()) && w != text) {
          add(w);
        }
        if (results.length >= limit + 2) break;
      }
    }

    // 3. Seed dictionary prefix matches.
    final dictKey = (mode == ScriptMode.roman && !pack.isLatin && isRomanInput)
        ? 'en'
        : pack.id;
    final dict = _seed[dictKey] ?? _seed['en']!;
    for (final w in dict) {
      if (results.length >= limit + 2) break;
      if (w.toLowerCase().startsWith(text.toLowerCase()) && w != text) {
        add(w);
      }
    }

    // 4. Native-script dictionary matches for native mode.
    if (!pack.isLatin && mode == ScriptMode.native) {
      final nd = _seed[pack.id];
      if (nd != null) {
        for (final w in nd) {
          if (results.length >= limit + 2) break;
          if (w.startsWith(text) && w != text) add(w);
        }
      }
    }

    // Always include the raw text as a candidate if we transformed it.
    if (results.isNotEmpty &&
        !pack.isLatin &&
        mode == ScriptMode.roman &&
        !seen.contains(text)) {
      add(text);
    }

    return results.take(limit).toList();
  }
}
