/// Build-time configurable Gemini API key pool.
library;

class GeminiKeyPool {
  GeminiKeyPool(List<String> keys)
      : _keys = keys.isEmpty ? const [''] : List.unmodifiable(keys),
        _failed = <int>{};

  final List<String> _keys;
  final Set<int> _failed;
  int _index = 0;

  factory GeminiKeyPool.production() {
    const configured = String.fromEnvironment('GEMINI_API_KEYS');
    final keys = configured.split(RegExp(r'[,\n]')).map((e) => e.trim())
        .where((e) => e.isNotEmpty).toList();
    return GeminiKeyPool(keys);
  }

  int get length => _keys.length;
  int get healthyCount => _keys.length - _failed.length;
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

  static bool isKeyError({int? httpStatus, String? message}) {
    if (httpStatus == 401 || httpStatus == 403 || httpStatus == 429) return true;
    final text = (message ?? '').toLowerCase();
    if (text.contains('api_key_invalid') || text.contains('invalid api key') ||
        text.contains('rate limit') || text.contains('resource_exhausted') ||
        text.contains('quota')) return true;
    return httpStatus == 400 && text.contains('key') && text.contains('invalid');
  }
}
