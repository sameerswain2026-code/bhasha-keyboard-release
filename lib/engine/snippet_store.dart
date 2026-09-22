/// Device-local snippets and aliases, similar to a small personal dictionary.
/// Values are persisted by the keyboard controller; this class contains no
/// network calls and never sends conversation text to a server.
library;

class LocalSnippet {
  const LocalSnippet({required this.alias, required this.value});

  final String alias;
  final String value;

  Map<String, String> toJson() => {'alias': alias, 'value': value};

  static LocalSnippet? fromJson(Object? value) {
    if (value is! Map) return null;
    final alias = value['alias']?.toString().trim() ?? '';
    final text = value['value']?.toString() ?? '';
    if (alias.isEmpty || text.isEmpty) return null;
    return LocalSnippet(alias: alias, value: text);
  }
}

class LocalSnippetStore {
  final List<LocalSnippet> _items = [];

  List<LocalSnippet> get items => List.unmodifiable(_items);

  void restore(Iterable<LocalSnippet> values) {
    _items
      ..clear()
      ..addAll(values.take(100));
  }

  void put(String alias, String value) {
    final cleanAlias = alias.trim();
    final cleanValue = value.trim();
    if (cleanAlias.isEmpty || cleanValue.isEmpty) return;
    final key = normalize(cleanAlias);
    _items.removeWhere((item) => normalize(item.alias) == key);
    _items.insert(0, LocalSnippet(alias: cleanAlias, value: cleanValue));
    if (_items.length > 100) _items.removeLast();
  }

  void remove(String alias) {
    final key = normalize(alias);
    _items.removeWhere((item) => normalize(item.alias) == key);
  }

  String? expand(String input) {
    final key = normalize(input);
    if (key.isEmpty) return null;
    for (final item in _items) {
      if (normalize(item.alias) == key) return item.value;
    }
    return null;
  }

  List<String> suggestions(String input, {int limit = 3}) {
    final key = normalize(input);
    if (key.isEmpty) return const [];
    return _items
        .where((item) {
          final alias = normalize(item.alias);
          return alias.startsWith(key) || key.startsWith(alias);
        })
        .take(limit)
        .map((item) => item.value)
        .toList();
  }

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Personal pronunciation/accent dictionary. The left side is what speech
/// recognition commonly returns; the right side is the user's preferred
/// spelling. It is deliberately separate from snippets: dictionary entries
/// correct recognized words, while snippets expand shortcuts into full text.
class DictionaryEntry {
  const DictionaryEntry({required this.heard, required this.preferred});

  final String heard;
  final String preferred;

  Map<String, String> toJson() => {'heard': heard, 'preferred': preferred};

  static DictionaryEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final heard = value['heard']?.toString().trim() ?? '';
    final preferred = value['preferred']?.toString() ?? '';
    if (heard.isEmpty || preferred.isEmpty) return null;
    return DictionaryEntry(heard: heard, preferred: preferred);
  }
}

class LocalDictionary {
  final List<DictionaryEntry> _items = [];

  List<DictionaryEntry> get items => List.unmodifiable(_items);

  void restore(Iterable<DictionaryEntry> values) {
    _items
      ..clear()
      ..addAll(values.take(200));
  }

  void put(String heard, String preferred) {
    final left = heard.trim();
    final right = preferred.trim();
    if (left.isEmpty || right.isEmpty) return;
    final key = LocalSnippetStore.normalize(left);
    _items.removeWhere(
      (item) => LocalSnippetStore.normalize(item.heard) == key,
    );
    _items.insert(0, DictionaryEntry(heard: left, preferred: right));
    if (_items.length > 200) _items.removeLast();
  }

  void remove(String heard) {
    final key = LocalSnippetStore.normalize(heard);
    _items.removeWhere(
      (item) => LocalSnippetStore.normalize(item.heard) == key,
    );
  }

  String apply(String input) {
    var output = input;
    final exact = LocalSnippetStore.normalize(input);
    for (final item in _items) {
      if (LocalSnippetStore.normalize(item.heard) == exact)
        return item.preferred;
    }
    for (final item in _items) {
      output = output.replaceAll(
        RegExp(RegExp.escape(item.heard), caseSensitive: false),
        item.preferred,
      );
    }
    return output;
  }
}
