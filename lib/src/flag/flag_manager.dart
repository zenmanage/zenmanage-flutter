/// Flag manager for evaluating feature flags
library zenmanage.flag_manager;

import 'dart:async';

import 'flag.dart';
import '../api_client.dart';
import '../rule_engine.dart';
import '../cache/cache.dart';
import '../context/context.dart';
import '../exceptions/exceptions.dart';

/// Manages feature flag evaluation
///
/// Provides methods to check flags and retrieve flag values with type-safe accessors.
class FlagManager {
  /// Creates a flag manager
  FlagManager({
    required ApiClient apiClient,
    required Cache cache,
    required RuleEngine ruleEngine,
    int cacheTtl = 3600,
  })  : _apiClient = apiClient,
        _cache = cache,
        _ruleEngine = ruleEngine,
        _cacheTtl = cacheTtl;

  final ApiClient _apiClient;
  final Cache _cache;
  final RuleEngine _ruleEngine;
  final int _cacheTtl;
  final List<Context> _contexts = [];
  String? _cachedRules;
  DateTime? _lastFetchTime;

  /// Sets context for the next flag evaluations
  ///
  /// Context is used for personalization and targeting. Call this before
  /// checking flags if you want to provide user/entity information.
  ///
  /// Example:
  /// ```dart
  /// final manager = zenmanage.flags();
  /// manager.withContext(Context.user(id: 'user123', name: 'John'));
  /// final flag = await manager.single('new-dashboard');
  /// ```
  FlagManager withContext(Context context) {
    _contexts.clear();
    _contexts.add(context);
    return this;
  }

  /// Sets multiple contexts for the next flag evaluations
  FlagManager withContexts(List<Context> contexts) {
    _contexts.clear();
    _contexts.addAll(contexts);
    return this;
  }

  /// Clears all context
  FlagManager clearContext() {
    _contexts.clear();
    return this;
  }

  /// Prefetches and caches rules.
  ///
  /// Call this during app startup to warm up the SDK before first flag access.
  Future<void> prefetch({List<Context>? contexts}) async {
    if (contexts != null) {
      withContexts(contexts);
    }
    await _getRulesJson();
  }

  /// Evaluates a single flag by key
  ///
  /// Fetches rules from the API if not cached, then evaluates locally.
  /// Throws [FlagNotFoundException] if the flag doesn't exist.
  /// Throws [ApiException] if the API request fails and no cached rules exist.
  ///
  /// Example:
  /// ```dart
  /// final flag = await zenmanage.flags().single('new-dashboard');
  /// if (flag.isEnabled()) {
  ///   showNewDashboard();
  /// }
  /// ```
  Future<Flag> single(String flagKey, {dynamic defaultValue}) async {
    final rules = await _getRulesJson();

    final flag = _ruleEngine.evaluateFlag(
      flagKey: flagKey,
      rulesJson: rules,
      contexts: _contexts.isNotEmpty ? _contexts : null,
      defaultValue: defaultValue,
    );

    if (flag != null) {
      // Report usage in background
      unawaited(_apiClient.reportUsage(
        flagKey: flagKey,
        flagValue: flag.value,
        context: _contexts.isNotEmpty ? _contexts.first : null,
      ));

      return flag;
    }

    if (defaultValue != null) {
      final fallbackFlag = _flagFromDefault(flagKey, defaultValue);

      // Report usage in background, including the default value that was used
      unawaited(_apiClient.reportUsage(
        flagKey: flagKey,
        flagValue: fallbackFlag.value,
        context: _contexts.isNotEmpty ? _contexts.first : null,
        defaultValue: defaultValue,
      ));

      return fallbackFlag;
    }

    throw FlagNotFoundException(flagKey);
  }

  /// Builds a [Flag] from a caller-supplied default value when the flag
  /// couldn't be resolved from rules.
  Flag _flagFromDefault(String flagKey, dynamic defaultValue) {
    final String type;
    if (defaultValue is bool) {
      type = 'boolean';
    } else if (defaultValue is num) {
      type = 'number';
    } else {
      type = 'string';
    }

    return Flag(key: flagKey, value: defaultValue, type: type);
  }

  /// Retrieves all available flags
  ///
  /// Returns a list of all flags from the rules.
  /// Throws [ApiException] if the API request fails and no cached rules exist.
  ///
  /// Example:
  /// ```dart
  /// final flags = await zenmanage.flags().all();
  /// for (final flag in flags) {
  ///   print('\${flag.key}: \${flag.value}');
  /// }
  /// ```
  Future<List<Flag>> all() async {
    final rules = await _getRulesJson();

    return _ruleEngine.evaluateAllFlags(
      rulesJson: rules,
      contexts: _contexts.isNotEmpty ? _contexts : null,
    );
  }

  /// Retrieves a flag, or returns a default if not found
  ///
  /// Useful when you want a default value instead of an exception.
  ///
  /// Example:
  /// ```dart
  /// final flag = await zenmanage.flags()
  ///   .singleOrDefault('new-dashboard', Flag(
  ///     key: 'new-dashboard',
  ///     value: false,
  ///     type: 'boolean',
  ///   ));
  /// ```
  Future<Flag> singleOrDefault(String flagKey, Flag defaultFlag) async {
    try {
      return await single(flagKey);
    } catch (e) {
      return defaultFlag;
    }
  }

  /// Clears the rules cache
  Future<void> clearCache() async {
    await _cache.clear();
    _cachedRules = null;
    _lastFetchTime = null;
  }

  /// Retrieves and caches rules from the API
  Future<String> _getRulesJson() async {
    // Check if we have fresh cached rules
    if (_cachedRules != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inSeconds < _cacheTtl) {
      return _cachedRules!;
    }

    // Try to fetch from API
    try {
      final response = await _apiClient.fetchRules(
        contexts: _contexts.isNotEmpty ? _contexts : null,
      );

      final rulesJson = response['rules'] as String? ?? '';
      _cachedRules = rulesJson;
      _lastFetchTime = DateTime.now();

      // Update persistent cache
      await _cache.setRules(rulesJson);

      return rulesJson;
    } catch (e) {
      // Fall back to persistent cache
      final cachedRules = await _cache.getRules();
      if (cachedRules != null && cachedRules.isNotEmpty) {
        _cachedRules = cachedRules;
        return cachedRules;
      }

      // No cache available, re-throw the error
      rethrow;
    }
  }
}
