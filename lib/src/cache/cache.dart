/// Cache interface for Zenmanage
library;

/// Interface for caching rules and flag evaluations
abstract interface class Cache {
  /// Stores rules in cache
  ///
  /// Returns true if successful, false otherwise
  Future<bool> setRules(String rules);

  /// Retrieves cached rules
  ///
  /// Returns null if not found or expired
  Future<String?> getRules();

  /// Clears all cached data
  Future<void> clear();

  /// Gets the cache backend name
  String get backendName;
}
