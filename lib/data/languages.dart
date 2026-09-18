/// Language Platform - 22 configured Indian languages + English base.
/// Language packs are pure configurable DATA, never hard-coded into UI.
library;

/// Script family determines which transliteration/layout engine is used.
enum ScriptFamily { latin, brahmic, arabic, olChiki, meeteiMayek }

/// Input mode for a language.
enum ScriptMode { native, roman }

class LanguagePack {
  final String id; // stable identifier
  final String englishName;
  final String nativeName;
  final String locale; // BCP-47 style
  final ScriptFamily family;

  /// Unicode block base offset for Brahmic scripts (e.g. 0x0900 Devanagari).
  final int scriptBase;

  final bool supportsNative;
  final bool supportsRoman;
  final bool voiceAvailable;

  /// Sarvam AI language code (BCP-47). Defaults to [locale]; set only
  /// where Sarvam's code differs (e.g. Odia: or-IN -> od-IN).
  final String? sarvamCodeOverride;

  /// Script-specific transliteration overrides (roman token -> output),
  /// applied before the generic engine.
  final Map<String, String> overrides;

  /// Fold table: relative Brahmic offsets that are unassigned in this
  /// script get folded to a substitute offset (e.g. Tamil aspirates).
  final Map<int, int> foldOffsets;

  const LanguagePack({
    required this.id,
    required this.englishName,
    required this.nativeName,
    required this.locale,
    required this.family,
    this.scriptBase = 0,
    this.supportsNative = true,
    this.supportsRoman = true,
    this.voiceAvailable = true,
    this.overrides = const {},
    this.foldOffsets = const {},
    this.sarvamCodeOverride,
  });

  bool get isLatin => family == ScriptFamily.latin;

  /// Language code used for Sarvam AI speech recognition.
  String get sarvamCode => sarvamCodeOverride ?? locale;
}

/// Tamil folds: aspirated/voiced consonants unassigned in the Tamil block
/// are folded to their nearest assigned letter.
const Map<int, int> _tamilFolds = {
  0x16: 0x15, // kh -> k
  0x17: 0x15, // g -> k
  0x18: 0x15, // gh -> k
  0x1B: 0x1A, // chh -> ch
  0x1D: 0x1C, // jh -> j
  0x20: 0x1F, // Th -> T
  0x21: 0x1F, // D -> T
  0x22: 0x1F, // Dh -> T
  0x25: 0x24, // th -> t
  0x26: 0x24, // d -> t
  0x27: 0x24, // dh -> t
  0x2B: 0x2A, // ph -> p
  0x2C: 0x2A, // b -> p
  0x2D: 0x2A, // bh -> p
  0x36: 0x38, // sh -> s (0x0BB6 exists but keep simple set small)
};

/// The 22 scheduled Indian languages + English.
/// This list is product data; UI reads it dynamically.
const List<LanguagePack> kLanguagePacks = [
  LanguagePack(
    id: 'en',
    englishName: 'English',
    nativeName: 'English',
    locale: 'en-IN',
    family: ScriptFamily.latin,
    supportsNative: false,
    supportsRoman: true,
  ),
  LanguagePack(
    id: 'hi',
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
    locale: 'hi-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'bn',
    englishName: 'Bengali',
    nativeName: 'বাংলা',
    locale: 'bn-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0980,
    overrides: {'v': 'ভ', 'w': 'ও'},
  ),
  LanguagePack(
    id: 'as',
    englishName: 'Assamese',
    nativeName: 'অসমীয়া',
    locale: 'as-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0980,
    overrides: {'r': 'ৰ', 'v': 'ৱ', 'w': 'ৱ'},
  ),
  LanguagePack(
    id: 'te',
    englishName: 'Telugu',
    nativeName: 'తెలుగు',
    locale: 'te-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0C00,
  ),
  LanguagePack(
    id: 'mr',
    englishName: 'Marathi',
    nativeName: 'मराठी',
    locale: 'mr-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'ta',
    englishName: 'Tamil',
    nativeName: 'தமிழ்',
    locale: 'ta-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0B80,
    foldOffsets: _tamilFolds,
  ),
  LanguagePack(
    id: 'gu',
    englishName: 'Gujarati',
    nativeName: 'ગુજરાતી',
    locale: 'gu-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0A80,
  ),
  LanguagePack(
    id: 'ur',
    englishName: 'Urdu',
    nativeName: 'اردو',
    locale: 'ur-IN',
    family: ScriptFamily.arabic,
  ),
  LanguagePack(
    id: 'kn',
    englishName: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    locale: 'kn-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0C80,
  ),
  LanguagePack(
    id: 'or',
    englishName: 'Odia',
    nativeName: 'ଓଡ଼ିଆ',
    locale: 'or-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0B00,
    sarvamCodeOverride: 'od-IN', // Sarvam uses od-IN for Odia
  ),
  LanguagePack(
    id: 'ml',
    englishName: 'Malayalam',
    nativeName: 'മലയാളം',
    locale: 'ml-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0D00,
  ),
  LanguagePack(
    id: 'pa',
    englishName: 'Punjabi',
    nativeName: 'ਪੰਜਾਬੀ',
    locale: 'pa-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0A00,
  ),
  LanguagePack(
    id: 'sa',
    englishName: 'Sanskrit',
    nativeName: 'संस्कृतम्',
    locale: 'sa-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'ne',
    englishName: 'Nepali',
    nativeName: 'नेपाली',
    locale: 'ne-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'mai',
    englishName: 'Maithili',
    nativeName: 'मैथिली',
    locale: 'mai-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'kok',
    englishName: 'Konkani',
    nativeName: 'कोंकणी',
    locale: 'kok-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'doi',
    englishName: 'Dogri',
    nativeName: 'डोगरी',
    locale: 'doi-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'brx',
    englishName: 'Bodo',
    nativeName: 'बड़ो',
    locale: 'brx-IN',
    family: ScriptFamily.brahmic,
    scriptBase: 0x0900,
  ),
  LanguagePack(
    id: 'ks',
    englishName: 'Kashmiri',
    nativeName: 'کٲشُر',
    locale: 'ks-IN',
    family: ScriptFamily.arabic,
  ),
  LanguagePack(
    id: 'sd',
    englishName: 'Sindhi',
    nativeName: 'سنڌي',
    locale: 'sd-IN',
    family: ScriptFamily.arabic,
  ),
  LanguagePack(
    id: 'sat',
    englishName: 'Santali',
    nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ',
    locale: 'sat-IN',
    family: ScriptFamily.olChiki,
  ),
  LanguagePack(
    id: 'mni',
    englishName: 'Manipuri',
    nativeName: 'ꯃꯤꯇꯩꯂꯣꯟ',
    locale: 'mni-IN',
    family: ScriptFamily.meeteiMayek,
  ),
];

class LanguageRegistry {
  static LanguagePack byId(String id) => kLanguagePacks.firstWhere(
    (p) => p.id == id,
    orElse: () => kLanguagePacks.first,
  );

  static List<LanguagePack> get all => kLanguagePacks;

  static List<LanguagePack> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return kLanguagePacks;
    return kLanguagePacks
        .where(
          (p) =>
              p.englishName.toLowerCase().contains(q) ||
              p.nativeName.contains(query.trim()) ||
              p.id.contains(q),
        )
        .toList();
  }
}
