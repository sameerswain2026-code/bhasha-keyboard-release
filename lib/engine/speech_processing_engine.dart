/// Deterministic, offline speech cleanup used before optional AI polishing.
///
/// The engine is deliberately conservative: when confidence is low it returns
/// the original transcript rather than deleting meaningful speech. It handles
/// repeated words for every script and common self-correction markers in
/// several supported Indian/English languages.
library;

import '../data/languages.dart';

class SpeechProcessingEngine {
  const SpeechProcessingEngine();

  static const Map<String, List<String>> _markers = {
    'en': ['no', 'i mean', 'actually', 'sorry', 'rather', 'wait'],
    'hi': ['नहीं', 'नहीं नहीं', 'मेरा मतलब', 'असल में', 'रुको', 'सॉरी'],
    'bn': ['না', 'আসলে', 'মানে', 'দুঃখিত'],
    'or': ['ନାହିଁ', 'ଆସଲେ', 'ମାନେ', 'ସରି'],
    'mr': ['नाही', 'म्हणजे', 'खरं तर', 'सॉरी'],
    'gu': ['ના', 'એટલે', 'ખરેખર', 'સોરી'],
    'pa': ['ਨਹੀਂ', 'ਮੇਰਾ ਮਤਲਬ', 'ਅਸਲ ਵਿੱਚ', 'ਸੌਰੀ'],
    'ta': ['இல்லை', 'அதாவது', 'உண்மையில்', 'மன்னிக்கவும்'],
    'te': ['కాదు', 'అంటే', 'నిజానికి', 'క్షమించండి'],
    'kn': ['ಇಲ್ಲ', 'ಅಂದರೆ', 'ವಾಸ್ತವವಾಗಿ', 'ಕ್ಷಮಿಸಿ'],
    'ml': ['അല്ല', 'അതായത്', 'യഥാർത്ഥത്തിൽ', 'ക്ഷമിക്കണം'],
    'ur': ['نہیں', 'میرا مطلب', 'اصل میں', 'سوری'],
  };

  String process(
    String input, {
    required LanguagePack language,
    bool smartCorrection = false,
  }) {
    final original = input.trim();
    if (!smartCorrection || original.isEmpty) return original;
    var text = _removeAccidentalDuplicates(original);
    text = _replaceSelfCorrection(text, language.id);
    return text.trim().isEmpty ? original : text.trim();
  }

  String _removeAccidentalDuplicates(String input) {
    final words = input.split(RegExp(r'\s+'));
    if (words.length < 2) return input;
    final out = <String>[];
    for (final word in words) {
      if (out.isNotEmpty && _sameWord(out.last, word) && !_intentional(word)) {
        continue;
      }
      out.add(word);
    }
    return out.join(' ');
  }

  bool _sameWord(String a, String b) =>
      _clean(a).toLowerCase() == _clean(b).toLowerCase();

  String _clean(String value) => value.replaceAll(RegExp(r'[.,!?।॥]+$'), '');

  bool _intentional(String word) {
    final normalized = _clean(word).toLowerCase();
    return const {
      'बहुत',
      'very',
      'really',
      'so',
      'बहुतों',
    }.contains(normalized);
  }

  String _replaceSelfCorrection(String input, String languageId) {
    final lower = input.toLowerCase();
    final marker = (_markers[languageId] ?? _markers['en']!).firstWhere(
      (candidate) => lower.contains(candidate.toLowerCase()),
      orElse: () => '',
    );
    if (marker.isEmpty) return input;
    final markerIndex = lower.indexOf(marker.toLowerCase());
    if (markerIndex <= 0) return input;

    final before = input.substring(0, markerIndex).trim();
    final after = input
        .substring(markerIndex + marker.length)
        .trim()
        .replaceFirst(RegExp(r'^[,;:!?،؛]+\s*'), '');
    if (after.isEmpty) return input;
    final beforeWords = before.split(RegExp(r'\s+'));
    final afterWords = after.split(RegExp(r'\s+'));
    if (beforeWords.length < 2 || afterWords.length < 2) return input;

    // Find the stable tail shared by the abandoned and corrected phrases.
    var tail = 0;
    while (tail < beforeWords.length &&
        tail < afterWords.length &&
        _sameWord(
          beforeWords[beforeWords.length - 1 - tail],
          afterWords[afterWords.length - 1 - tail],
        )) {
      tail++;
    }
    if (tail == 0) return input;

    final oldPrefixLength = beforeWords.length - tail;
    final newPrefixLength = afterWords.length - tail;
    if (oldPrefixLength < 1 || newPrefixLength < 1) return input;

    final oldPrefix = beforeWords.take(oldPrefixLength).toList();
    final newPrefix = afterWords.take(newPrefixLength).toList();
    final sharedPrefix = _commonPrefixLength(oldPrefix, newPrefix);

    // If the speaker repeats the sentence prefix, the corrected phrase is
    // authoritative. Otherwise retain the stable original prefix and replace
    // only the abandoned part. This avoids destructive guesses.
    final replacement = sharedPrefix >= 1
        ? newPrefix
        : [...oldPrefix.take(oldPrefix.length - 1), ...newPrefix];
    final suffix = beforeWords.skip(oldPrefixLength).toList();
    return [...replacement, ...suffix].join(' ');
  }

  int _commonPrefixLength(List<String> a, List<String> b) {
    var count = 0;
    while (count < a.length &&
        count < b.length &&
        _sameWord(a[count], b[count])) {
      count++;
    }
    return count;
  }
}
