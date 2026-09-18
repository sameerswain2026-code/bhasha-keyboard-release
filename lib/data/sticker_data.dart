/// Offline illustrated-mascot sticker dataset (Gboard-style character
/// stickers - see reference screenshots), distinct from the plain-emoji
/// [EmojiEntry] set. Each entry points to a bundled PNG asset instead of
/// a unicode character, grouped into categories with keyword metadata
/// for search, mirroring emoji_data.dart's structure so the Sticker
/// panel can reuse the same category-tabs + search + recents UI pattern
/// as the Emoji panel.
library;

class StickerEntry {
  /// Stable identifier used for the "Recent" tab's persisted history
  /// (see KeyboardController.recentStickers / addRecentSticker).
  final String id;
  final String asset;
  final String label;
  final List<String> keywords;
  const StickerEntry(this.id, this.asset, this.label, this.keywords);
}

class StickerCategory {
  final String name;
  final String icon; // emoji glyph used as the compact tab icon
  final List<StickerEntry> stickers;
  const StickerCategory(this.name, this.icon, this.stickers);
}

const List<StickerCategory> kStickerCategories = [
  StickerCategory('Greetings', '👋', [
    StickerEntry('wave_hello', 'assets/stickers/wave_hello.png', 'Hello', [
      'hello',
      'hi',
      'wave',
      'bye',
      'greetings',
      'namaste',
    ]),
    StickerEntry(
      'namaste_thanks',
      'assets/stickers/namaste_thanks.png',
      'Thank you',
      ['namaste', 'thanks', 'thank you', 'pray', 'please', 'gratitude'],
    ),
    StickerEntry(
      'handshake_deal',
      'assets/stickers/handshake_deal.png',
      'Deal',
      ['handshake', 'deal', 'agree', 'welcome', 'nice to meet you'],
    ),
  ]),
  StickerCategory('Reactions', '😂', [
    StickerEntry('laughing', 'assets/stickers/laughing.png', 'LOL', [
      'laugh',
      'lol',
      'funny',
      'haha',
      'lmao',
    ]),
    StickerEntry(
      'shocked_surprised',
      'assets/stickers/shocked_surprised.png',
      'Shocked',
      ['shocked', 'surprised', 'omg', 'wow', 'mind blown', 'what'],
    ),
    StickerEntry('thumbs_up', 'assets/stickers/thumbs_up.png', 'Nice', [
      'thumbs up',
      'ok',
      'nice',
      'good job',
      'yes',
      'approve',
    ]),
    StickerEntry(
      'cool_sunglasses',
      'assets/stickers/cool_sunglasses.png',
      'Cool',
      ['cool', 'sunglasses', 'swag', 'awesome'],
    ),
  ]),
  StickerCategory('Love', '❤️', [
    StickerEntry('love_heart', 'assets/stickers/love_heart.png', 'Love you', [
      'love',
      'heart',
      'hug',
      'miss you',
      'like',
    ]),
    StickerEntry('blowing_kiss', 'assets/stickers/blowing_kiss.png', 'Kiss', [
      'kiss',
      'love',
      'sweet',
      'romance',
    ]),
  ]),
  StickerCategory('Moods', '😴', [
    StickerEntry('crying_sad', 'assets/stickers/crying_sad.png', 'Sad', [
      'sad',
      'cry',
      'crying',
      'sorry',
      'upset',
    ]),
    StickerEntry('sleeping', 'assets/stickers/sleeping.png', 'Sleepy', [
      'sleep',
      'tired',
      'good night',
      'zzz',
    ]),
    StickerEntry(
      'flexing_strong',
      'assets/stickers/flexing_strong.png',
      'Strong',
      ['strong', 'muscle', 'flex', 'gym', 'power'],
    ),
  ]),
  StickerCategory('Celebrate', '🎉', [
    StickerEntry(
      'celebration_party',
      'assets/stickers/celebration_party.png',
      'Party!',
      ['party', 'celebrate', 'congrats', 'birthday', 'yay', 'woohoo'],
    ),
  ]),
];

/// Flat lookup for resolving a persisted sticker id (Recent tab) back to
/// its full [StickerEntry].
final Map<String, StickerEntry> kStickersById = {
  for (final cat in kStickerCategories)
    for (final s in cat.stickers) s.id: s,
};

class StickerSearch {
  static List<StickerEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <StickerEntry>[];
    for (final cat in kStickerCategories) {
      for (final s in cat.stickers) {
        if (s.label.toLowerCase().contains(q) ||
            s.keywords.any((k) => k.contains(q))) {
          results.add(s);
        }
      }
    }
    return results;
  }
}
