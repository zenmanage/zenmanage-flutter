/// Null cache implementation (no caching)
library zenmanage.cache.nocache;

import 'cache.dart';

/// A cache implementation that doesn't cache anything
///
/// Useful for testing or when caching is not desired.
/// Every flag evaluation will require a fresh fetch from the API.
final class NullCache implements Cache {
  @override
  Future<bool> setRules(String rules) async => true;

  @override
  Future<String?> getRules() async => null;

  @override
  Future<void> clear() async {}

  @override
  String get backendName => 'null';
}
