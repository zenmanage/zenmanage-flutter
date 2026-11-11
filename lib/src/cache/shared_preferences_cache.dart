/// SharedPreferences-based cache implementation for Flutter
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../exceptions/exceptions.dart';
import 'cache.dart';

/// Cache implementation using Flutter's SharedPreferences
///
/// Suitable for Flutter mobile apps. Persists rules to the device's
/// local storage for quick subsequent app launches.
final class SharedPreferencesCache implements Cache {
  /// Creates a new SharedPreferencesCache
  SharedPreferencesCache({
    String? namespace,
  }) : _namespace = 'zenmanage_${namespace ?? 'rules'}';

  final String _namespace;
  SharedPreferences? _prefs;

  /// Initializes the cache by loading SharedPreferences instance
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      throw CacheException(
        'Failed to initialize SharedPreferences: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> setRules(String rules) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return await _prefs!.setString(_namespace, rules);
    } catch (e) {
      throw CacheException(
        'Failed to cache rules: ${e.toString()}',
      );
    }
  }

  @override
  Future<String?> getRules() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!.getString(_namespace);
    } catch (e) {
      throw CacheException(
        'Failed to retrieve cached rules: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_namespace);
    } catch (e) {
      throw CacheException(
        'Failed to clear cache: ${e.toString()}',
      );
    }
  }

  @override
  String get backendName => 'shared_preferences';
}
