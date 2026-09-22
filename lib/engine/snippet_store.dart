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
