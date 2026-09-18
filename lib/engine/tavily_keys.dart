/// Build-time configurable Tavily API key pool.
library;

class TavilyKeyPool {
  TavilyKeyPool(List<String> keys)
      : _keys = keys.isEmpty ? const [''] : List.unmodifiable(keys),
        _failed = <int>{};

  final List<String> _keys;
  final Set<int> _failed;
  int _index = 0;

  factory TavilyKeyPool.production() {
    const configured = String.fromEnvironment('TAVILY_API_KEYS');
    final keys = configured.split(RegExp(r'[,\n]')).map((e) => e.trim())
        .where((e) => e.isNotEmpty).toList();
    return TavilyKeyPool(keys);
  }

  int get length => _keys.length;
  String get current => _keys[_index];

  void markHealthy(String key) {
    final i = _keys.indexOf(key);
    if (i >= 0) _failed.remove(i);
  }

  bool markFailed(String key) {
    final i = _keys.indexOf(key);
    if (i < 0) return false;
    _failed.add(i);
    for (var step = 1; step <= _keys.length; step++) {
      final next = (i + step) % _keys.length;
      if (!_failed.contains(next)) {
        _index = next;
        return true;
      }
    }
    _failed.clear();
    _index = 0;
    return false;
  }

  static bool isKeyError({int? httpStatus}) =>
      httpStatus == 401 || httpStatus == 403 || httpStatus == 429;
}
