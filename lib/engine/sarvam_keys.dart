/// Build-time configurable Sarvam API key pool.
library;

class SarvamKeyPool {
  SarvamKeyPool(List<String> keys)
    : _keys = keys.isEmpty ? const [''] : List.unmodifiable(keys),
      _failed = <int>{};

  final List<String> _keys;
  final Set<int> _failed;
  int _index = 0;

  factory SarvamKeyPool.production() {
    const configured = String.fromEnvironment('SARVAM_API_KEYS');
    final keys = configured
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return SarvamKeyPool(keys);
  }

  int get length => _keys.length;
  bool get hasUsableKey => _keys.any((key) => key.isNotEmpty);
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

  static bool isKeyError({int? httpStatus, int? closeCode, String? message}) {
    if (httpStatus == 401 ||
        httpStatus == 402 ||
        httpStatus == 403 ||
        httpStatus == 429)
      return true;
    if (closeCode == 4001 || closeCode == 4429) return true;
    final text = (message ?? '').toLowerCase();
    return text.contains('invalid') &&
            (text.contains('key') || text.contains('authentication')) ||
        text.contains('rate limit') ||
        text.contains('insufficient credits') ||
        text.contains('quota') ||
        text.contains('subscription expired');
  }
}
