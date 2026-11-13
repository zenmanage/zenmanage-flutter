/// Flag manager for evaluating feature flags
library;

import 'dart:async';

import 'flag.dart';
import '../api_client.dart';
import '../rule_engine.dart';
import '../cache/cache.dart';
import '../context/context.dart';
import '../exceptions/exceptions.dart';

/// The rules fetched from the API, shared by a [FlagManager] and every manager
/// forked from it so they all read (and refresh) one copy.
class _RulesStore {
  String? cachedRules;
  DateTime? lastFetchTime;
}

/// Manages feature flag evaluation
///
/// Provides methods to check flags and retrieve flag values with type-safe accessors.
///
/// The context set with [withContext] / [withContexts] belongs to this manager
/// only. [Zenmanage.flags] returns a new manager on every call, so a read never
/// picks up the context of another read.
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
        _cacheTtl = cacheTtl,
        _rules = _RulesStore();

  FlagManager._fork(FlagManager parent)
      : _apiClient = parent._apiClient,
        _cache = parent._cache,
        _ruleEngine = parent._ruleEngine,
        _cacheTtl = parent._cacheTtl,
        _rules = parent._rules;

  final ApiClient _apiClient;
  final Cache _cache;
  final RuleEngine _ruleEngine;
  final int _cacheTtl;
  final _RulesStore _rules;
  final List<Context> _contexts = [];

  /// Returns a new manager with no context that shares this manager's rules
  /// and caches.
  ///
  /// Each read should use its own manager, so that its context can't be
  /// replaced by another read that is in flight at the same time. This is what
  /// [Zenmanage.flags] does for you.
  FlagManager fork() => FlagManager._fork(this);

  /// Sets context for the next flag evaluations
  ///
  /// Context is used for personalization and targeting. Call this before
  /// checking flags if you want to provide user/entity information.
  ///
  /// The context applies to this manager only.
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
  /// The [contexts] are used for this fetch only; they are not kept for later
  /// reads.
  Future<void> prefetch({List<Context>? contexts}) async {
    await _getRulesJson(List<Context>.of(contexts ?? _contexts));
  }

  /// Evaluates a single flag by key
  ///
  /// Fetches rules from the API if not cached, then evaluates locally.
  ///
  /// When [defaultValue] is given, it is returned (and reported as the default
  /// used) if the flag isn't in the rules, and also if the rules can't be
  /// loaded at all: an invalid key, no network, and nothing cached.
  ///
  /// Without a [defaultValue]:
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
    // Take this read's contexts now. The rules fetch below is async, and the
    // contexts must not change under it if this manager is reused meanwhile.
    final contexts = List<Context>.of(_contexts);

    // If the rules can't be loaded, serve the caller's default instead of
    // throwing. Without a default there is nothing to serve, so surface the
    // load error.
    String? rules;
    try {
      rules = await _getRulesJson(contexts);
    } on ZenmanageException {
      if (defaultValue == null) rethrow;
    }

    final flag = rules == null
        ? null
        : _ruleEngine.evaluateFlag(
            flagKey: flagKey,
            rulesJson: rules,
            contexts: contexts.isNotEmpty ? contexts : null,
            defaultValue: defaultValue,
          );

    if (flag != null) {
      // Report usage in background, including the default value so it's
      // recorded even when the flag was found and evaluated normally
      unawaited(_apiClient.reportUsage(
        flagKey: flagKey,
        flagValue: flag.value,
        context: contexts.isNotEmpty ? contexts.first : null,
        defaultValue: defaultValue,
      ));

      return flag;
    }

    if (defaultValue != null) {
      final fallbackFlag = _flagFromDefault(flagKey, defaultValue);

      // Report usage in background, including the default value that was used
      unawaited(_apiClient.reportUsage(
        flagKey: flagKey,
        flagValue: fallbackFlag.value,
        context: contexts.isNotEmpty ? contexts.first : null,
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
    } else if (defaultValue is Map || defaultValue is List) {
      type = 'json';
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
    final contexts = List<Context>.of(_contexts);
    final rules = await _getRulesJson(contexts);

    return _ruleEngine.evaluateAllFlags(
      rulesJson: rules,
      contexts: contexts.isNotEmpty ? contexts : null,
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
    _rules.cachedRules = null;
    _rules.lastFetchTime = null;
  }

  /// Retrieves and caches rules from the API
  Future<String> _getRulesJson(List<Context> contexts) async {
    // Check if we have fresh cached rules
    final cached = _rules.cachedRules;
    final fetchedAt = _rules.lastFetchTime;
    if (cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt).inSeconds < _cacheTtl) {
      return cached;
    }

    // Try to fetch from API
    try {
      final response = await _apiClient.fetchRules(
        contexts: contexts.isNotEmpty ? contexts : null,
      );

      final rulesJson = response['rules'] as String? ?? '';
      _rules.cachedRules = rulesJson;
      _rules.lastFetchTime = DateTime.now();

      // Update persistent cache
      await _cache.setRules(rulesJson);

      return rulesJson;
    } catch (e) {
      // Fall back to persistent cache
      final cachedRules = await _cache.getRules();
      if (cachedRules != null && cachedRules.isNotEmpty) {
        _rules.cachedRules = cachedRules;
        return cachedRules;
      }

      // No cache available, re-throw the error
      rethrow;
    }
  }
}
