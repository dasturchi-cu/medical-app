/// Oddiy xotira keshi — bir marta yuklangan ma'lumotni TTL davomida qayta ishlatadi.
class MemoryTtlCache<T> {
  MemoryTtlCache({required this.ttl});

  final Duration ttl;
  final Map<String, _Entry<T>> _entries = {};
  final Map<String, Future<T>> _inFlight = {};

  T? peek(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void put(String key, T value) {
    _entries[key] = _Entry(value, DateTime.now());
  }

  void invalidate(String key) {
    _entries.remove(key);
    _inFlight.remove(key);
  }

  void invalidatePrefix(String prefix) {
    final keys = _entries.keys.where((k) => k.startsWith(prefix)).toList(growable: false);
    for (final key in keys) {
      invalidate(key);
    }
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  Future<T> getOrFetch(String key, Future<T> Function() fetch, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = peek(key);
      if (cached != null) return cached;
    }
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = fetch().then((value) {
      put(key, value);
      _inFlight.remove(key);
      return value;
    }).catchError((Object e, StackTrace st) {
      _inFlight.remove(key);
      Error.throwWithStackTrace(e, st);
    });
    _inFlight[key] = future;
    return future;
  }
}

class _Entry<T> {
  _Entry(this.value, this.at);
  final T value;
  final DateTime at;
}
