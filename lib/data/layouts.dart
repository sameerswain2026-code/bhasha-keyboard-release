/// Keyboard layout definitions - alpha (QWERTY + native), numeric, symbols.
library;

import '../data/languages.dart';

class LayoutRows {
  final List<List<String>> rows;
  const LayoutRows(this.rows);
}

/// Ordered inventories used by the optional native language packs. Keeping an
/// explicit inventory avoids displaying unassigned Unicode code points (the
/// old block scan produced blank/missing-looking keys) and follows the
/// alphabet-first, signs-after layout used by Indic keyboards.
const Map<String, String> kNativeCharacterSets = {
  'hi':
      'अआइईउऊऋएऐओऔअंअःकखगघङचछजझञटठडढणतथदधनपफबभमयरलवशषसहळक्षत्रज्ञ़ँंः्ािीुूृेैोौॅॉॐ०१२३४५६७८९',
  'bn':
      'অআইঈউঊঋএঐওঔঅংঅঃকখগঘঙচছজঝঞটঠডঢণতথদধনপফবভমযরলশষসহড়ঢ়য়ক্ষজ্ঞ়ঁংঃ্ািীুূৃেৈোৌৗৠ০১২৩৪৫৬৭৮৯',
  'as':
      'অআইঈউঊঋএঐওঔঅংঅঃকখগঘঙচছজঝঞটঠডঢণতথদধনপফবভমযৰলশষসহড়ঢ়ৱক্ষজ্ঞ়ঁংঃ্ািীুূৃেৈোৌৗ০১২৩৪৫৬৭৮৯',
  'or':
      'ଅଆଇଈଉଊଋଏଐଓଔଅଂଅଃକଖଗଘଙଚଛଜଝଞଟଠଡଢଣତଥଦଧନପଫବଭମଯରଲୱଶଷସହଳକ୍ଷଜ୍ଞଡ଼ଢ଼ୟ୍ାିୀୁୂୃେୈୋୌଁଂଃ୦୧୨୩୪୫୬୭୮୯',
  'ta': 'அஆஇஈஉஊஎஏஐஒஓஔஃகஙசஞடணதநபமயரலவழளறனஜஷஸஹக்ஷ்ாிீுூெேைொோௌ௧௨௩௪௫௬௭௮௯',
  'te':
      'అఆఇఈఉఊఋౠఎఏఐఒఓఔఅంఅఃకఖగఘఙచఛజఝఞటఠడఢణతథదధనపఫబభమయరలవశషసహళక్షజ్ఞఱ్ంః్ాిీుూృౄెేైొోౌ౧౨౩౪౫౬౭౮౯',
  'kn':
      'ಅಆಇಈಉಊಋೠಎಏಐಒಓಔಅಂಅಃಕಖಗಘಙಚಛಜಝಞಟಠಡಢಣತಥದಧನಪಫಬಭಮಯರಲವಶಷಸಹಳಕ್ಷಜ್ಞಱಂಃ್ಾಿೀುೂೃೄೆೇೈೊೋೌ೦೧೨೩೪೫೬೭೮೯',
  'ml':
      'അആഇഈഉഊഋൠഎഏഐഒഓഔഅംഅഃകഖഗഘങചഛജഝഞടഠഡഢണതഥദധനപഫബഭമയരലവശഷസഹളഴറനക്ഷജ്ഞ്ാിീുൂൃെേൈൊോൌംഃ൦൧൨൩൪൫൬൭൮൯',
  'gu':
      'અઆઇઈઉઊઋએઐઓઔઅંઅઃકખગઘઙચછજઝઞટઠડઢણતથદધનપફબભમયરલવશષસહળક્ષજ્ઞૅૉ્ાિીુૂૃેૈોૌંઃ૦૧૨૩૪૫૬૭૮૯',
  'pa':
      'ਅਆਇਈਉਊਏਐਓਔਅੰਅਃਕਖਗਘਙਚਛਜਝਞਟਠਡਢਣਤਥਦਧਨਪਫਬਭਮਯਰਲਵਸ਼ਸਹੜਖ਼ਗ਼ਜ਼ਫ਼ਸ਼੍ਾਂਿੀੁੂੇੈੋੌੰਃ੦੧੨੩੪੫੬੭੮੯',
  'ur':
      'ا ب پ ت ٹ ث ج چ ح خ د ڈ ذ ر ڑ ز ژ س ش ص ض ط ظ ع غ ف ق ک گ ل م ن ں و ہ ھ ء ی ے آ ئ ۓ ُ َ ِ ْ ّ ۔ ۰۱۲۳۴۵۶۷۸۹',
  'ks':
      'ا آ ب پ ت ٹ ث ج چ ح خ د ڈ ذ ر ڑ ز ژ س ش ص ض ط ظ ع غ ف ق ک گ ل م ن ں و ہ ھ ء ی ے ٲ ٳ ۂ ۃ َ ُ ِ ْ ّ ۔ ۰۱۲۳۴۵۶۷۸۹',
  'sd':
      'ا آ ب ٻ ڀ پ ت ٽ ٺ ث ج ڄ ڃ چ ڇ ح خ د ڊ ڌ ڏ ذ ر ڙ ز ژ س ش ص ض ط ظ ع غ ف ق ڪ ک گ ڳ ل م ن ڻ و ه ھ ء ي ئ َ ُ ِ ْ ّ ۔ ۰۱۲۳۴۵۶۷۸۹',
  'sat': 'ᱚᱛᱜᱝᱞᱟᱠᱡᱢᱣᱤᱥᱦᱧᱨᱩᱪᱫᱬᱭᱮᱯᱰᱱᱲᱳᱴᱵᱶᱷᱸᱹᱺᱻᱼᱽ',
  'mni': 'ꯀꯁꯂꯃꯄꯅꯆꯇꯈꯉꯊꯋꯌꯍꯎꯏꯐꯑꯒꯓꯔꯕꯖꯗꯘꯙꯚꯛꯜꯝꯞꯟꯠꯡꯢꯣꯤꯥꯦꯧꯨꯩꯪ꯫',
};

String _nativeCharactersFor(LanguagePack pack) {
  if (kNativeCharacterSets.containsKey(pack.id))
    return kNativeCharacterSets[pack.id]!;
  if (pack.family == ScriptFamily.brahmic) return kNativeCharacterSets['hi']!;
  if (pack.family == ScriptFamily.arabic) return kNativeCharacterSets['ur']!;
  return '';
}

/// Split the ordered native alphabet into comfortable Gboard-like pages.
List<LayoutRows> nativeLayoutPagesFor(LanguagePack pack) {
  final first = kNativeLayouts[pack.id] ?? kDevanagariFallback;
  final raw = _nativeCharactersFor(pack);
  final chars = <String>[];
  final seen = <String>{};
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    if (seen.add(ch)) chars.add(ch);
  }
  if (chars.isEmpty) return [first];

  // The first page is the familiar Gboard/InScript-inspired arrangement:
  // matras and signs first, then high-frequency consonants. The previous
  // implementation discarded this arrangement and scanned the Unicode
  // inventory into arbitrary 10/9/8 chunks, which made every downloaded
  // language feel randomly ordered. Keep the hand-curated base page and put
  // the complete alphabet in deterministic continuation pages.
  final used = first.rows.expand((row) => row).toSet();
  final remainder = chars.where((ch) => !used.contains(ch)).toList();
  final pages = <LayoutRows>[];
  pages.add(first);
  for (var i = 0; i < remainder.length; i += 27) {
    final end = i + 27 < remainder.length ? i + 27 : remainder.length;
    final page = remainder.sublist(i, end);
    pages.add(
      LayoutRows([
        page.take(10).toList(),
        page.skip(10).take(9).toList(),
        page.skip(19).take(8).toList(),
      ]),
    );
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
