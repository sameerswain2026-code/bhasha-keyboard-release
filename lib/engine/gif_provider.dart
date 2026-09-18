/// GIF provider abstraction. Inline keyboard-sized results.
///
/// Curated, offline-bundled catalog of real Giphy media IDs (stable
/// `media.giphy.com/media/<id>/...` CDN links - same link shape Giphy's
/// own web/app clients use, so these keep working without a live API
/// key). Search is byte-for-byte synchronous and un-debounced: Gboard's
/// GIF search visibly narrows results on every keystroke, and with a
/// small in-memory catalog there is no latency reason to hide that
/// behind a timer - matching that "real-time" feel is more important
/// than the (now pointless) simulated-latency delay this used to add.
/// Insertion is always an explicit, clearly-labelled fallback (never a
/// blind raw-URL paste), since rich GIF content isn't insertable into
/// arbitrary host text fields.
library;

import 'package:flutter/material.dart' show Icons, IconData;

/// Category tabs shown by [GifPanel], mirroring Gboard's own top tab row
/// (see reference screenshot). "Trending" has no keyword filter of its
/// own - it always shows the full curated catalog (matching the panel's
/// original empty-query default).
enum GifCategory { trending, reactions, love, celebration, greetings }

const Map<GifCategory, String> kGifCategoryLabels = {
  GifCategory.trending: 'Trending',
  GifCategory.reactions: 'Reactions',
  GifCategory.love: 'Love',
  GifCategory.celebration: 'Celebrate',
  GifCategory.greetings: 'Greetings',
};

const Map<GifCategory, IconData> kGifCategoryIcons = {
  GifCategory.trending: Icons.whatshot,
  GifCategory.reactions: Icons.emoji_emotions_outlined,
  GifCategory.love: Icons.favorite_border,
  GifCategory.celebration: Icons.celebration_outlined,
  GifCategory.greetings: Icons.waving_hand_outlined,
};

class GifItem {
  final String id;
  final String title;
  final String previewUrl;
  final String shareUrl;
  final GifCategory category;
  const GifItem({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.shareUrl,
    this.category = GifCategory.trending,
  });
}

abstract class GifProvider {
  List<GifItem> search(String query);
  List<GifItem> trending();
  List<GifItem> byCategory(GifCategory category);
}

/// Curated GIF provider using stable public Giphy media CDN URLs (the
/// `/200w.gif` fixed-width preview + `/giphy.gif` original share link
/// pattern). Over 130 entries spanning every category so search results
/// feel comparable to Gboard's variety instead of a handful of items.
class CuratedGifProvider implements GifProvider {
  static const List<GifItem> _catalog = [
    GifItem(
      id: 'l1J9u3TZfpmeDLkD6',
      title: 'angry look now omg talking whos',
      previewUrl: 'https://media.giphy.com/media/l1J9u3TZfpmeDLkD6/200w.gif',
      shareUrl: 'https://media.giphy.com/media/l1J9u3TZfpmeDLkD6/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'TGi1zmIHpDRsrxtoPq',
      title: 'angry',
      previewUrl: 'https://media.giphy.com/media/TGi1zmIHpDRsrxtoPq/200w.gif',
      shareUrl: 'https://media.giphy.com/media/TGi1zmIHpDRsrxtoPq/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '11tTNkNy1SdXGg',
      title: 'angry inside out',
      previewUrl: 'https://media.giphy.com/media/11tTNkNy1SdXGg/200w.gif',
      shareUrl: 'https://media.giphy.com/media/11tTNkNy1SdXGg/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'RuYPi0HyBnOxy',
      title: 'angry black moan snake',
      previewUrl: 'https://media.giphy.com/media/RuYPi0HyBnOxy/200w.gif',
      shareUrl: 'https://media.giphy.com/media/RuYPi0HyBnOxy/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '3ohhwmQ0xIg8W3pHd6',
      title: 'birthday happy rainbow',
      previewUrl: 'https://media.giphy.com/media/3ohhwmQ0xIg8W3pHd6/200w.gif',
      shareUrl: 'https://media.giphy.com/media/3ohhwmQ0xIg8W3pHd6/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'ZJjs83nX1Z87EWvGCp',
      title: 'birthday happy reaction',
      previewUrl: 'https://media.giphy.com/media/ZJjs83nX1Z87EWvGCp/200w.gif',
      shareUrl: 'https://media.giphy.com/media/ZJjs83nX1Z87EWvGCp/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'DXhmNiA8F1i4fLnMdb',
      title: 'birthday dancing happy',
      previewUrl: 'https://media.giphy.com/media/DXhmNiA8F1i4fLnMdb/200w.gif',
      shareUrl: 'https://media.giphy.com/media/DXhmNiA8F1i4fLnMdb/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'SRO0ZwmImic0',
      title: 'birthday happy reaction',
      previewUrl: 'https://media.giphy.com/media/SRO0ZwmImic0/200w.gif',
      shareUrl: 'https://media.giphy.com/media/SRO0ZwmImic0/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'txtNuq1l2TqYQNmW21',
      title: 'bored sabrina',
      previewUrl: 'https://media.giphy.com/media/txtNuq1l2TqYQNmW21/200w.gif',
      shareUrl: 'https://media.giphy.com/media/txtNuq1l2TqYQNmW21/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'rq6c5xD7leHW8',
      title: 'big bored lebowski reaction the',
      previewUrl: 'https://media.giphy.com/media/rq6c5xD7leHW8/200w.gif',
      shareUrl: 'https://media.giphy.com/media/rq6c5xD7leHW8/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'IlQRLRjObIFNWEhpEs',
      title: 'bored cat excited girl',
      previewUrl: 'https://media.giphy.com/media/IlQRLRjObIFNWEhpEs/200w.gif',
      shareUrl: 'https://media.giphy.com/media/IlQRLRjObIFNWEhpEs/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'HfFccPJv7a9k4',
      title: 'bored come on',
      previewUrl: 'https://media.giphy.com/media/HfFccPJv7a9k4/200w.gif',
      shareUrl: 'https://media.giphy.com/media/HfFccPJv7a9k4/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'lsJCkIKV6AT28',
      title: 'celebrate rep',
      previewUrl: 'https://media.giphy.com/media/lsJCkIKV6AT28/200w.gif',
      shareUrl: 'https://media.giphy.com/media/lsJCkIKV6AT28/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'axu6dFuca4HKM',
      title: 'celebrate ferrell happy will',
      previewUrl: 'https://media.giphy.com/media/axu6dFuca4HKM/200w.gif',
      shareUrl: 'https://media.giphy.com/media/axu6dFuca4HKM/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'l0MYt5jPR6QX5pnqM',
      title: 'celebrate hard office party the',
      previewUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/200w.gif',
      shareUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: '1PMVNNKVIL8Ig',
      title: 'celebrate excited new year',
      previewUrl: 'https://media.giphy.com/media/1PMVNNKVIL8Ig/200w.gif',
      shareUrl: 'https://media.giphy.com/media/1PMVNNKVIL8Ig/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'YRuFixSNWFVcXaxpmX',
      title: 'clapping done well',
      previewUrl: 'https://media.giphy.com/media/YRuFixSNWFVcXaxpmX/200w.gif',
      shareUrl: 'https://media.giphy.com/media/YRuFixSNWFVcXaxpmX/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'QTAVEex4ANH1pcdg16',
      title: '6 clapping excited season',
      previewUrl: 'https://media.giphy.com/media/QTAVEex4ANH1pcdg16/200w.gif',
      shareUrl: 'https://media.giphy.com/media/QTAVEex4ANH1pcdg16/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'zfNAMCrhSQzte',
      title: 'clapping raccoon',
      previewUrl: 'https://media.giphy.com/media/zfNAMCrhSQzte/200w.gif',
      shareUrl: 'https://media.giphy.com/media/zfNAMCrhSQzte/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'Xz4SUPTyL1pw11i5Ux',
      title: 'clapping game great',
      previewUrl: 'https://media.giphy.com/media/Xz4SUPTyL1pw11i5Ux/200w.gif',
      shareUrl: 'https://media.giphy.com/media/Xz4SUPTyL1pw11i5Ux/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'ji6zzUZwNIuLS',
      title: 'confused girl little',
      previewUrl: 'https://media.giphy.com/media/ji6zzUZwNIuLS/200w.gif',
      shareUrl: 'https://media.giphy.com/media/ji6zzUZwNIuLS/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '3EiNpweH34XGoQcq9Q',
      title: 'brule confused steve',
      previewUrl: 'https://media.giphy.com/media/3EiNpweH34XGoQcq9Q/200w.gif',
      shareUrl: 'https://media.giphy.com/media/3EiNpweH34XGoQcq9Q/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'fa1AV8UvZvfBFOIt7F',
      title: 'confused thinking what',
      previewUrl: 'https://media.giphy.com/media/fa1AV8UvZvfBFOIt7F/200w.gif',
      shareUrl: 'https://media.giphy.com/media/fa1AV8UvZvfBFOIt7F/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'YVPwi7L2izTJS',
      title: 'boys confused park trailer',
      previewUrl: 'https://media.giphy.com/media/YVPwi7L2izTJS/200w.gif',
      shareUrl: 'https://media.giphy.com/media/YVPwi7L2izTJS/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'hv14mGOF3MY7wDKPkE',
      title: 'congratulations done happy well',
      previewUrl: 'https://media.giphy.com/media/hv14mGOF3MY7wDKPkE/200w.gif',
      shareUrl: 'https://media.giphy.com/media/hv14mGOF3MY7wDKPkE/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'J5Xr9k7qK5KGRi45vp',
      title: 'congratulations',
      previewUrl: 'https://media.giphy.com/media/J5Xr9k7qK5KGRi45vp/200w.gif',
      shareUrl: 'https://media.giphy.com/media/J5Xr9k7qK5KGRi45vp/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'mzZbByY3c3eoqy9CaP',
      title: 'congratulations go happy to way',
      previewUrl: 'https://media.giphy.com/media/mzZbByY3c3eoqy9CaP/200w.gif',
      shareUrl: 'https://media.giphy.com/media/mzZbByY3c3eoqy9CaP/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'F7JHDDqWaSPaglz24x',
      title: 'celebration congratulations hearts',
      previewUrl: 'https://media.giphy.com/media/F7JHDDqWaSPaglz24x/200w.gif',
      shareUrl: 'https://media.giphy.com/media/F7JHDDqWaSPaglz24x/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'qUB8aayj9DNQI',
      title: 'amy cool poehler what',
      previewUrl: 'https://media.giphy.com/media/qUB8aayj9DNQI/200w.gif',
      shareUrl: 'https://media.giphy.com/media/qUB8aayj9DNQI/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '62PP2yEIAZF6g',
      title: 'breakfast club cool reaction the',
      previewUrl: 'https://media.giphy.com/media/62PP2yEIAZF6g/200w.gif',
      shareUrl: 'https://media.giphy.com/media/62PP2yEIAZF6g/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'xoHntNXFYkfzGAftEv',
      title: 'cool gosling ryan sunglasses',
      previewUrl: 'https://media.giphy.com/media/xoHntNXFYkfzGAftEv/200w.gif',
      shareUrl: 'https://media.giphy.com/media/xoHntNXFYkfzGAftEv/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'mgqefqwSbToPe',
      title: 'charlie cool day ok',
      previewUrl: 'https://media.giphy.com/media/mgqefqwSbToPe/200w.gif',
      shareUrl: 'https://media.giphy.com/media/mgqefqwSbToPe/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '10tIjpzIu8fe0',
      title: 'crying inside out sad',
      previewUrl: 'https://media.giphy.com/media/10tIjpzIu8fe0/200w.gif',
      shareUrl: 'https://media.giphy.com/media/10tIjpzIu8fe0/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'd2lcHJTG5Tscg',
      title: 'anderson anthony crying sad',
      previewUrl: 'https://media.giphy.com/media/d2lcHJTG5Tscg/200w.gif',
      shareUrl: 'https://media.giphy.com/media/d2lcHJTG5Tscg/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'P53TSsopKicrm',
      title: 'and crying lilo sad stitch',
      previewUrl: 'https://media.giphy.com/media/P53TSsopKicrm/200w.gif',
      shareUrl: 'https://media.giphy.com/media/P53TSsopKicrm/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '2WxWfiavndgcM',
      title: 'crying doctor sad who',
      previewUrl: 'https://media.giphy.com/media/2WxWfiavndgcM/200w.gif',
      shareUrl: 'https://media.giphy.com/media/2WxWfiavndgcM/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'ujTVMASREzuRbH6zy5',
      title: 'dance dancing',
      previewUrl: 'https://media.giphy.com/media/ujTVMASREzuRbH6zy5/200w.gif',
      shareUrl: 'https://media.giphy.com/media/ujTVMASREzuRbH6zy5/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'tsMAPZ96MHPlvP6OtE',
      title: 'dance penguin',
      previewUrl: 'https://media.giphy.com/media/tsMAPZ96MHPlvP6OtE/200w.gif',
      shareUrl: 'https://media.giphy.com/media/tsMAPZ96MHPlvP6OtE/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'V7jkATiqn3mRie2LI2',
      title: 'dance dancing',
      previewUrl: 'https://media.giphy.com/media/V7jkATiqn3mRie2LI2/200w.gif',
      shareUrl: 'https://media.giphy.com/media/V7jkATiqn3mRie2LI2/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'UZxzsNx1kpZZwTCSSp',
      title: 'dance dancing',
      previewUrl: 'https://media.giphy.com/media/UZxzsNx1kpZZwTCSSp/200w.gif',
      shareUrl: 'https://media.giphy.com/media/UZxzsNx1kpZZwTCSSp/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'OfkGZ5H2H3f8Y',
      title: 'american excited horror story',
      previewUrl: 'https://media.giphy.com/media/OfkGZ5H2H3f8Y/200w.gif',
      shareUrl: 'https://media.giphy.com/media/OfkGZ5H2H3f8Y/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'ZjbhFnvZMt61JQxvON',
      title: 'excited girl happy little',
      previewUrl: 'https://media.giphy.com/media/ZjbhFnvZMt61JQxvON/200w.gif',
      shareUrl: 'https://media.giphy.com/media/ZjbhFnvZMt61JQxvON/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'UO5elnTqo4vSg',
      title: 'excited flirting so',
      previewUrl: 'https://media.giphy.com/media/UO5elnTqo4vSg/200w.gif',
      shareUrl: 'https://media.giphy.com/media/UO5elnTqo4vSg/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'F6PFPjc3K0CPe',
      title: 'excited feliz happy',
      previewUrl: 'https://media.giphy.com/media/F6PFPjc3K0CPe/200w.gif',
      shareUrl: 'https://media.giphy.com/media/F6PFPjc3K0CPe/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'DMnQAyk56tfX0O436G',
      title: 'good morning travel',
      previewUrl: 'https://media.giphy.com/media/DMnQAyk56tfX0O436G/200w.gif',
      shareUrl: 'https://media.giphy.com/media/DMnQAyk56tfX0O436G/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'ZdNdNH9LehfMJOVnaP',
      title: 'good morning swerk',
      previewUrl: 'https://media.giphy.com/media/ZdNdNH9LehfMJOVnaP/200w.gif',
      shareUrl: 'https://media.giphy.com/media/ZdNdNH9LehfMJOVnaP/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'QBw8TKimBs2pdH7dC0',
      title: 'good hello morning',
      previewUrl: 'https://media.giphy.com/media/QBw8TKimBs2pdH7dC0/200w.gif',
      shareUrl: 'https://media.giphy.com/media/QBw8TKimBs2pdH7dC0/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: '8eoyDtGnfC7kI',
      title: 'good morning',
      previewUrl: 'https://media.giphy.com/media/8eoyDtGnfC7kI/200w.gif',
      shareUrl: 'https://media.giphy.com/media/8eoyDtGnfC7kI/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'dftdiku6jrzq9UYSPz',
      title: 'good night space',
      previewUrl: 'https://media.giphy.com/media/dftdiku6jrzq9UYSPz/200w.gif',
      shareUrl: 'https://media.giphy.com/media/dftdiku6jrzq9UYSPz/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'AS1gcB11vrXJKp5P8T',
      title: 'good love night',
      previewUrl: 'https://media.giphy.com/media/AS1gcB11vrXJKp5P8T/200w.gif',
      shareUrl: 'https://media.giphy.com/media/AS1gcB11vrXJKp5P8T/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'GiZzkhK5bpTJn6y7ve',
      title: 'good night tired',
      previewUrl: 'https://media.giphy.com/media/GiZzkhK5bpTJn6y7ve/200w.gif',
      shareUrl: 'https://media.giphy.com/media/GiZzkhK5bpTJn6y7ve/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'qHTB3Q0vcCPIjR9zJ0',
      title: 'good love night',
      previewUrl: 'https://media.giphy.com/media/qHTB3Q0vcCPIjR9zJ0/200w.gif',
      shareUrl: 'https://media.giphy.com/media/qHTB3Q0vcCPIjR9zJ0/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'kaBU6pgv0OsPHz2yxy',
      title: 'goodbye miss you',
      previewUrl: 'https://media.giphy.com/media/kaBU6pgv0OsPHz2yxy/200w.gif',
      shareUrl: 'https://media.giphy.com/media/kaBU6pgv0OsPHz2yxy/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'jUwpNzg9IcyrK',
      title: 'goodbye homer scared simpson',
      previewUrl: 'https://media.giphy.com/media/jUwpNzg9IcyrK/200w.gif',
      shareUrl: 'https://media.giphy.com/media/jUwpNzg9IcyrK/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'LTFbyWuELIlqlXGLeZ',
      title: 'goodbye story toy',
      previewUrl: 'https://media.giphy.com/media/LTFbyWuELIlqlXGLeZ/200w.gif',
      shareUrl: 'https://media.giphy.com/media/LTFbyWuELIlqlXGLeZ/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'UQaRUOLveyjNC',
      title: 'bye good goodbye',
      previewUrl: 'https://media.giphy.com/media/UQaRUOLveyjNC/200w.gif',
      shareUrl: 'https://media.giphy.com/media/UQaRUOLveyjNC/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'aQYR1p8saOQla',
      title: 'excited happy so',
      previewUrl: 'https://media.giphy.com/media/aQYR1p8saOQla/200w.gif',
      shareUrl: 'https://media.giphy.com/media/aQYR1p8saOQla/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'fUQ4rhUZJYiQsas6WD',
      title: 'happy sesame street',
      previewUrl: 'https://media.giphy.com/media/fUQ4rhUZJYiQsas6WD/200w.gif',
      shareUrl: 'https://media.giphy.com/media/fUQ4rhUZJYiQsas6WD/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'BWplyaNrHRjRvweNjS',
      title: 'happy joy',
      previewUrl: 'https://media.giphy.com/media/BWplyaNrHRjRvweNjS/200w.gif',
      shareUrl: 'https://media.giphy.com/media/BWplyaNrHRjRvweNjS/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'qdxDab2ZKCLq3qI6kO',
      title: 'happy',
      previewUrl: 'https://media.giphy.com/media/qdxDab2ZKCLq3qI6kO/200w.gif',
      shareUrl: 'https://media.giphy.com/media/qdxDab2ZKCLq3qI6kO/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'CK0Eg2ymtfzTO2yVJD',
      title: 'finding hello nemo',
      previewUrl: 'https://media.giphy.com/media/CK0Eg2ymtfzTO2yVJD/200w.gif',
      shareUrl: 'https://media.giphy.com/media/CK0Eg2ymtfzTO2yVJD/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'dzaUX7CAG0Ihi',
      title: 'hello moving pictures',
      previewUrl: 'https://media.giphy.com/media/dzaUX7CAG0Ihi/200w.gif',
      shareUrl: 'https://media.giphy.com/media/dzaUX7CAG0Ihi/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'xT9IgG50Fb7Mi0prBC',
      title: 'hanks hello tom',
      previewUrl: 'https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/200w.gif',
      shareUrl: 'https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'Cmr1OMJ2FN0B2',
      title: 'hello madagascar of penguins',
      previewUrl: 'https://media.giphy.com/media/Cmr1OMJ2FN0B2/200w.gif',
      shareUrl: 'https://media.giphy.com/media/Cmr1OMJ2FN0B2/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: '7Wcyq7KvKFNTO',
      title: 'hug i love me you',
      previewUrl: 'https://media.giphy.com/media/7Wcyq7KvKFNTO/200w.gif',
      shareUrl: 'https://media.giphy.com/media/7Wcyq7KvKFNTO/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: '5zM3QKTv7F4FsJav9R',
      title: 'dogs embracing hug',
      previewUrl: 'https://media.giphy.com/media/5zM3QKTv7F4FsJav9R/200w.gif',
      shareUrl: 'https://media.giphy.com/media/5zM3QKTv7F4FsJav9R/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: 'EvYHHSntaIl5m',
      title: 'hug inc monsters',
      previewUrl: 'https://media.giphy.com/media/EvYHHSntaIl5m/200w.gif',
      shareUrl: 'https://media.giphy.com/media/EvYHHSntaIl5m/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: '4CTlTWDNqcBva',
      title: 'get hug hugging in',
      previewUrl: 'https://media.giphy.com/media/4CTlTWDNqcBva/200w.gif',
      shareUrl: 'https://media.giphy.com/media/4CTlTWDNqcBva/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: 'vdbrUjzrUEGly',
      title: 'hungry',
      previewUrl: 'https://media.giphy.com/media/vdbrUjzrUEGly/200w.gif',
      shareUrl: 'https://media.giphy.com/media/vdbrUjzrUEGly/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'jKaFXbKyZFja0',
      title: 'excited hungry pooh the winnie',
      previewUrl: 'https://media.giphy.com/media/jKaFXbKyZFja0/200w.gif',
      shareUrl: 'https://media.giphy.com/media/jKaFXbKyZFja0/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'UTkm6euG3wabBiUeQu',
      title: 'and hungry jerry reaction tom',
      previewUrl: 'https://media.giphy.com/media/UTkm6euG3wabBiUeQu/200w.gif',
      shareUrl: 'https://media.giphy.com/media/UTkm6euG3wabBiUeQu/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'rMS89RxHOzjGw',
      title: 'child hungry',
      previewUrl: 'https://media.giphy.com/media/rMS89RxHOzjGw/200w.gif',
      shareUrl: 'https://media.giphy.com/media/rMS89RxHOzjGw/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'XHeLeuirRbwptHhSWd',
      title: 'laughing lol meme',
      previewUrl: 'https://media.giphy.com/media/XHeLeuirRbwptHhSWd/200w.gif',
      shareUrl: 'https://media.giphy.com/media/XHeLeuirRbwptHhSWd/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'GCO5WNzFmlc0vjK8cA',
      title: 'cracking laughing lol up',
      previewUrl: 'https://media.giphy.com/media/GCO5WNzFmlc0vjK8cA/200w.gif',
      shareUrl: 'https://media.giphy.com/media/GCO5WNzFmlc0vjK8cA/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'gj0QdZ9FgqGhOBNlFS',
      title: 'cracking laughing lol up',
      previewUrl: 'https://media.giphy.com/media/gj0QdZ9FgqGhOBNlFS/200w.gif',
      shareUrl: 'https://media.giphy.com/media/gj0QdZ9FgqGhOBNlFS/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'l0ExayQDzrI2xOb8A',
      title: 'day laughing lol mothers',
      previewUrl: 'https://media.giphy.com/media/l0ExayQDzrI2xOb8A/200w.gif',
      shareUrl: 'https://media.giphy.com/media/l0ExayQDzrI2xOb8A/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '4N1wOi78ZGzSB6H7vK',
      title: 'day love valentines',
      previewUrl: 'https://media.giphy.com/media/4N1wOi78ZGzSB6H7vK/200w.gif',
      shareUrl: 'https://media.giphy.com/media/4N1wOi78ZGzSB6H7vK/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: 'n9HfdJCqnh01e99KtB',
      title: 'happy i love you',
      previewUrl: 'https://media.giphy.com/media/n9HfdJCqnh01e99KtB/200w.gif',
      shareUrl: 'https://media.giphy.com/media/n9HfdJCqnh01e99KtB/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: 't8xgPfC5oNIRMrNooe',
      title: 'dog love',
      previewUrl: 'https://media.giphy.com/media/t8xgPfC5oNIRMrNooe/200w.gif',
      shareUrl: 'https://media.giphy.com/media/t8xgPfC5oNIRMrNooe/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: 'RB46T9ysjzDEs',
      title: 'i love you',
      previewUrl: 'https://media.giphy.com/media/RB46T9ysjzDEs/200w.gif',
      shareUrl: 'https://media.giphy.com/media/RB46T9ysjzDEs/giphy.gif',
      category: GifCategory.love,
    ),
    GifItem(
      id: 'fXnRObM8Q0RkOmR5nf',
      title: 'funny meme no way',
      previewUrl: 'https://media.giphy.com/media/fXnRObM8Q0RkOmR5nf/200w.gif',
      shareUrl: 'https://media.giphy.com/media/fXnRObM8Q0RkOmR5nf/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'wYyTHMm50f4Dm',
      title: 'im no not way',
      previewUrl: 'https://media.giphy.com/media/wYyTHMm50f4Dm/200w.gif',
      shareUrl: 'https://media.giphy.com/media/wYyTHMm50f4Dm/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'gnE4FFhtFoLKM',
      title: 'minions no way',
      previewUrl: 'https://media.giphy.com/media/gnE4FFhtFoLKM/200w.gif',
      shareUrl: 'https://media.giphy.com/media/gnE4FFhtFoLKM/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'eKrgVyZ7zLvJrgZNZn',
      title: 'baby no way',
      previewUrl: 'https://media.giphy.com/media/eKrgVyZ7zLvJrgZNZn/200w.gif',
      shareUrl: 'https://media.giphy.com/media/eKrgVyZ7zLvJrgZNZn/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'DFNd1yVyRjmF2',
      title: 'jennifer lawrence ok thumbs up',
      previewUrl: 'https://media.giphy.com/media/DFNd1yVyRjmF2/200w.gif',
      shareUrl: 'https://media.giphy.com/media/DFNd1yVyRjmF2/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '3ohhwfwxg4d1h82LxS',
      title: 'creek ok schitts yes',
      previewUrl: 'https://media.giphy.com/media/3ohhwfwxg4d1h82LxS/200w.gif',
      shareUrl: 'https://media.giphy.com/media/3ohhwfwxg4d1h82LxS/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'L3X9GvVhP1nY23Ah6u',
      title: 'ok okaay',
      previewUrl: 'https://media.giphy.com/media/L3X9GvVhP1nY23Ah6u/200w.gif',
      shareUrl: 'https://media.giphy.com/media/L3X9GvVhP1nY23Ah6u/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'xSM46ernAUN3y',
      title: 'happy if ok say so you',
      previewUrl: 'https://media.giphy.com/media/xSM46ernAUN3y/200w.gif',
      shareUrl: 'https://media.giphy.com/media/xSM46ernAUN3y/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'xUA7aT1vNqVWHPY1cA',
      title: 'party vaughn vince',
      previewUrl: 'https://media.giphy.com/media/xUA7aT1vNqVWHPY1cA/200w.gif',
      shareUrl: 'https://media.giphy.com/media/xUA7aT1vNqVWHPY1cA/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'j1mMc3lpVX67AVIpDe',
      title: 'dance party',
      previewUrl: 'https://media.giphy.com/media/j1mMc3lpVX67AVIpDe/200w.gif',
      shareUrl: 'https://media.giphy.com/media/j1mMc3lpVX67AVIpDe/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'blSTtZehjAZ8I',
      title: 'dance dancing party',
      previewUrl: 'https://media.giphy.com/media/blSTtZehjAZ8I/200w.gif',
      shareUrl: 'https://media.giphy.com/media/blSTtZehjAZ8I/giphy.gif',
      category: GifCategory.celebration,
    ),
    GifItem(
      id: 'zZbf6UpZslp3nvFjIR',
      title: 'boots in please puss',
      previewUrl: 'https://media.giphy.com/media/zZbf6UpZslp3nvFjIR/200w.gif',
      shareUrl: 'https://media.giphy.com/media/zZbf6UpZslp3nvFjIR/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: '43wR1f8QU9KApWKjYt',
      title: 'please stantwitter',
      previewUrl: 'https://media.giphy.com/media/43wR1f8QU9KApWKjYt/200w.gif',
      shareUrl: 'https://media.giphy.com/media/43wR1f8QU9KApWKjYt/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'YZOsKxJfmvzG0',
      title: 'please',
      previewUrl: 'https://media.giphy.com/media/YZOsKxJfmvzG0/200w.gif',
      shareUrl: 'https://media.giphy.com/media/YZOsKxJfmvzG0/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'MFIsOqzodLr7ewnkUb',
      title: 'please sad',
      previewUrl: 'https://media.giphy.com/media/MFIsOqzodLr7ewnkUb/200w.gif',
      shareUrl: 'https://media.giphy.com/media/MFIsOqzodLr7ewnkUb/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'lGBecpB2dIMwt6ohfI',
      title: 'cat cute sad smile',
      previewUrl: 'https://media.giphy.com/media/lGBecpB2dIMwt6ohfI/200w.gif',
      shareUrl: 'https://media.giphy.com/media/lGBecpB2dIMwt6ohfI/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'q2qxiBO5prG9i',
      title: 'inside out sad sadness',
      previewUrl: 'https://media.giphy.com/media/q2qxiBO5prG9i/200w.gif',
      shareUrl: 'https://media.giphy.com/media/q2qxiBO5prG9i/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'H6cmWzp6LGFvqjidB7',
      title: 'cry sad',
      previewUrl: 'https://media.giphy.com/media/H6cmWzp6LGFvqjidB7/200w.gif',
      shareUrl: 'https://media.giphy.com/media/H6cmWzp6LGFvqjidB7/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'Lz6971fkGSgCMOOncl',
      title: 'cat iraq sad',
      previewUrl: 'https://media.giphy.com/media/Lz6971fkGSgCMOOncl/200w.gif',
      shareUrl: 'https://media.giphy.com/media/Lz6971fkGSgCMOOncl/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'SUBxai0moNW7K',
      title: 'scared spongebob',
      previewUrl: 'https://media.giphy.com/media/SUBxai0moNW7K/200w.gif',
      shareUrl: 'https://media.giphy.com/media/SUBxai0moNW7K/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'cA0TiRmuetO1szgShj',
      title: 'scared scream what',
      previewUrl: 'https://media.giphy.com/media/cA0TiRmuetO1szgShj/200w.gif',
      shareUrl: 'https://media.giphy.com/media/cA0TiRmuetO1szgShj/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'bEVKYB487Lqxy',
      title: 'frog kermit scared the',
      previewUrl: 'https://media.giphy.com/media/bEVKYB487Lqxy/200w.gif',
      shareUrl: 'https://media.giphy.com/media/bEVKYB487Lqxy/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '51Uiuy5QBZNkoF3b2Z',
      title: 'dog scared',
      previewUrl: 'https://media.giphy.com/media/51Uiuy5QBZNkoF3b2Z/200w.gif',
      shareUrl: 'https://media.giphy.com/media/51Uiuy5QBZNkoF3b2Z/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'bEs40jYsdQjmM',
      title: 'and jerry sleepy tired tom',
      previewUrl: 'https://media.giphy.com/media/bEs40jYsdQjmM/200w.gif',
      shareUrl: 'https://media.giphy.com/media/bEs40jYsdQjmM/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'mF4k0YXIHDHzy',
      title: 'night sleepy tired',
      previewUrl: 'https://media.giphy.com/media/mF4k0YXIHDHzy/200w.gif',
      shareUrl: 'https://media.giphy.com/media/mF4k0YXIHDHzy/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'ROjjp6hqqgACs',
      title: 'dog sleepy',
      previewUrl: 'https://media.giphy.com/media/ROjjp6hqqgACs/200w.gif',
      shareUrl: 'https://media.giphy.com/media/ROjjp6hqqgACs/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'xT8qBvH1pAhtfSx52U',
      title: 'baby sleepy tired',
      previewUrl: 'https://media.giphy.com/media/xT8qBvH1pAhtfSx52U/200w.gif',
      shareUrl: 'https://media.giphy.com/media/xT8qBvH1pAhtfSx52U/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'fV8iuSEwLQ6005diSh',
      title: 'sorry',
      previewUrl: 'https://media.giphy.com/media/fV8iuSEwLQ6005diSh/200w.gif',
      shareUrl: 'https://media.giphy.com/media/fV8iuSEwLQ6005diSh/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: '5Gb6pmAu8o0Ba',
      title: 'kitten sorry',
      previewUrl: 'https://media.giphy.com/media/5Gb6pmAu8o0Ba/200w.gif',
      shareUrl: 'https://media.giphy.com/media/5Gb6pmAu8o0Ba/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'RFDXes97gboYg',
      title: 'caine michael sorry',
      previewUrl: 'https://media.giphy.com/media/RFDXes97gboYg/200w.gif',
      shareUrl: 'https://media.giphy.com/media/RFDXes97gboYg/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: 'XYEEvoX0Ub69ZgN9ai',
      title: 'aww sad sorry',
      previewUrl: 'https://media.giphy.com/media/XYEEvoX0Ub69ZgN9ai/200w.gif',
      shareUrl: 'https://media.giphy.com/media/XYEEvoX0Ub69ZgN9ai/giphy.gif',
      category: GifCategory.greetings,
    ),
    GifItem(
      id: '5VKbvrjxpVJCM',
      title: 'and parks recreation surprised wow',
      previewUrl: 'https://media.giphy.com/media/5VKbvrjxpVJCM/200w.gif',
      shareUrl: 'https://media.giphy.com/media/5VKbvrjxpVJCM/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'QUENDfi6DEMLzQ0CKt',
      title: 'say surprised word wow',
      previewUrl: 'https://media.giphy.com/media/QUENDfi6DEMLzQ0CKt/200w.gif',
      shareUrl: 'https://media.giphy.com/media/QUENDfi6DEMLzQ0CKt/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'lxxOGaDRk4f7R5TkBd',
      title: 'speed surprised wow',
      previewUrl: 'https://media.giphy.com/media/lxxOGaDRk4f7R5TkBd/200w.gif',
      shareUrl: 'https://media.giphy.com/media/lxxOGaDRk4f7R5TkBd/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '2XskdWuNUyqElkKe4bm',
      title: 'brule steve surprised what',
      previewUrl: 'https://media.giphy.com/media/2XskdWuNUyqElkKe4bm/200w.gif',
      shareUrl: 'https://media.giphy.com/media/2XskdWuNUyqElkKe4bm/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'd3mlE7uhX8KFgEmY',
      title: 'about it think thinking',
      previewUrl: 'https://media.giphy.com/media/d3mlE7uhX8KFgEmY/200w.gif',
      shareUrl: 'https://media.giphy.com/media/d3mlE7uhX8KFgEmY/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'DfSXiR60W9MVq',
      title: 'math thinking',
      previewUrl: 'https://media.giphy.com/media/DfSXiR60W9MVq/200w.gif',
      shareUrl: 'https://media.giphy.com/media/DfSXiR60W9MVq/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'a5viI92PAF89q',
      title: 'think thinking',
      previewUrl: 'https://media.giphy.com/media/a5viI92PAF89q/200w.gif',
      shareUrl: 'https://media.giphy.com/media/a5viI92PAF89q/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'kPtv3UIPrv36cjxqLs',
      title: 'ferrell lol thinking will',
      previewUrl: 'https://media.giphy.com/media/kPtv3UIPrv36cjxqLs/200w.gif',
      shareUrl: 'https://media.giphy.com/media/kPtv3UIPrv36cjxqLs/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '111ebonMs90YLu',
      title: 'ok thumbs up',
      previewUrl: 'https://media.giphy.com/media/111ebonMs90YLu/200w.gif',
      shareUrl: 'https://media.giphy.com/media/111ebonMs90YLu/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'JwjBy94VzDd6',
      title: 'no problem thumbs up yes',
      previewUrl: 'https://media.giphy.com/media/JwjBy94VzDd6/200w.gif',
      shareUrl: 'https://media.giphy.com/media/JwjBy94VzDd6/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'CvZuv5m5cKl8c',
      title: 'no problem reaction thumbs up',
      previewUrl: 'https://media.giphy.com/media/CvZuv5m5cKl8c/200w.gif',
      shareUrl: 'https://media.giphy.com/media/CvZuv5m5cKl8c/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'eBCnpuRGBhQGY',
      title: 'tired zzz',
      previewUrl: 'https://media.giphy.com/media/eBCnpuRGBhQGY/200w.gif',
      shareUrl: 'https://media.giphy.com/media/eBCnpuRGBhQGY/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'xchUhdPj5IRyw',
      title: 'spongebob squarepants tired',
      previewUrl: 'https://media.giphy.com/media/xchUhdPj5IRyw/200w.gif',
      shareUrl: 'https://media.giphy.com/media/xchUhdPj5IRyw/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'l1KVaj5UcbHwrBMqI',
      title: 'family sad time tired',
      previewUrl: 'https://media.giphy.com/media/l1KVaj5UcbHwrBMqI/200w.gif',
      shareUrl: 'https://media.giphy.com/media/l1KVaj5UcbHwrBMqI/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'l0y6gXwXCDPAQ',
      title: 'reggie trending wayne week',
      previewUrl: 'https://media.giphy.com/media/l0y6gXwXCDPAQ/200w.gif',
      shareUrl: 'https://media.giphy.com/media/l0y6gXwXCDPAQ/giphy.gif',
      category: GifCategory.trending,
    ),
    GifItem(
      id: '9SfWGhN97TIBpmdRem',
      title: 'hearts i love trending you',
      previewUrl: 'https://media.giphy.com/media/9SfWGhN97TIBpmdRem/200w.gif',
      shareUrl: 'https://media.giphy.com/media/9SfWGhN97TIBpmdRem/giphy.gif',
      category: GifCategory.trending,
    ),
    GifItem(
      id: 'WG4uYteu6J0teNVxpT',
      title: 'hearts i love trending you',
      previewUrl: 'https://media.giphy.com/media/WG4uYteu6J0teNVxpT/200w.gif',
      shareUrl: 'https://media.giphy.com/media/WG4uYteu6J0teNVxpT/giphy.gif',
      category: GifCategory.trending,
    ),
    GifItem(
      id: 'gjCdY6N8pn7HnFvKhy',
      title: 'bollywood trending',
      previewUrl: 'https://media.giphy.com/media/gjCdY6N8pn7HnFvKhy/200w.gif',
      shareUrl: 'https://media.giphy.com/media/gjCdY6N8pn7HnFvKhy/giphy.gif',
      category: GifCategory.trending,
    ),
    GifItem(
      id: '9sJ7ZldhfGyn4KuOyP',
      title: '4 andy season wow',
      previewUrl: 'https://media.giphy.com/media/9sJ7ZldhfGyn4KuOyP/200w.gif',
      shareUrl: 'https://media.giphy.com/media/9sJ7ZldhfGyn4KuOyP/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'oYtVHSxngR3lC',
      title: 'chris farley wow',
      previewUrl: 'https://media.giphy.com/media/oYtVHSxngR3lC/200w.gif',
      shareUrl: 'https://media.giphy.com/media/oYtVHSxngR3lC/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'aWPGuTlDqq2yc',
      title: 'god my oh reaction wow',
      previewUrl: 'https://media.giphy.com/media/aWPGuTlDqq2yc/200w.gif',
      shareUrl: 'https://media.giphy.com/media/aWPGuTlDqq2yc/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '89x4osEodHEoo',
      title: 'dynamite napoleon yes',
      previewUrl: 'https://media.giphy.com/media/89x4osEodHEoo/200w.gif',
      shareUrl: 'https://media.giphy.com/media/89x4osEodHEoo/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: '10Jpr9KSaXLchW',
      title: 'jack nicholson yes',
      previewUrl: 'https://media.giphy.com/media/10Jpr9KSaXLchW/200w.gif',
      shareUrl: 'https://media.giphy.com/media/10Jpr9KSaXLchW/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'DffShiJ47fPqM',
      title: 'pizza yes',
      previewUrl: 'https://media.giphy.com/media/DffShiJ47fPqM/200w.gif',
      shareUrl: 'https://media.giphy.com/media/DffShiJ47fPqM/giphy.gif',
      category: GifCategory.reactions,
    ),
    GifItem(
      id: 'NEvPzZ8bd1V4Y',
      title: 'of proud yes you',
      previewUrl: 'https://media.giphy.com/media/NEvPzZ8bd1V4Y/200w.gif',
      shareUrl: 'https://media.giphy.com/media/NEvPzZ8bd1V4Y/giphy.gif',
      category: GifCategory.reactions,
    ),
  ];

  @override
  List<GifItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return trending();
    // Split into words so multi-word queries ("good morning") match
    // catalog entries whose keyword title contains all of them in any
    // order, not just as one exact substring.
    final terms = q.split(RegExp(r'\s+'));
    return _catalog
        .where((g) => terms.every((t) => g.title.contains(t)))
        .toList();
  }

  @override
  List<GifItem> trending() => _catalog;

  @override
  List<GifItem> byCategory(GifCategory category) {
    if (category == GifCategory.trending) return _catalog;
    return _catalog.where((g) => g.category == category).toList();
  }
}

/// Thin synchronous wrapper kept for API stability with callers that
/// previously awaited an async engine. No debounce/timer/delay: with a
/// small bundled catalog, filtering is instant, so search results
/// narrow live on every keystroke exactly like Gboard's own GIF search.
class GifEngine {
  GifEngine({GifProvider? provider})
    : _provider = provider ?? CuratedGifProvider();
  final GifProvider _provider;

  List<GifItem> trending() => _provider.trending();
  List<GifItem> byCategory(GifCategory category) =>
      _provider.byCategory(category);

  /// Instant (synchronous, no debounce) search - the whole point of the
  /// "real-time" fix. Results narrow live on every keystroke exactly like
  /// Gboard's own GIF search, with no Future/Timer indirection needed.
  List<GifItem> search(String query) => _provider.search(query);

  /// Callback-style variant kept for API stability with any callers that
  /// previously awaited an async engine.
  void searchDebounced(String query, void Function(List<GifItem>) onResults) {
    onResults(_provider.search(query));
  }

  void dispose() {}
}
