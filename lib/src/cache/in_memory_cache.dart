/// In-memory cache implementation
library;

import 'cache.dart';

/// Simple in-memory cache implementation
///
/// Stores rules in memory for fast access. Cache is lost when the app closes.
/// Suitable for short-lived applications or testing.
final class InMemoryCache implements Cache {
  String? _cachedRules;

  @override
  Future<bool> setRules(String rules) async {
    _cachedRules = rules;
    return true;
  }

  @override
  Future<String?> getRules() async => _cachedRules;

  @override
  Future<void> clear() async {
    _cachedRules = null;
  }

  @override
  String get backendName => 'memory';
}
