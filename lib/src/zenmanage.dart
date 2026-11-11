/// Main Zenmanage SDK class
library zenmanage.main;

import 'api_client.dart';
import 'config/config.dart';
import 'context/context.dart';
import 'flag/flag_manager.dart';
import 'rule_engine.dart';

/// Main entry point for the Zenmanage Flutter SDK
///
/// Provides access to feature flags with local evaluation.
///
/// Example usage:
/// ```dart
/// final zenmanage = Zenmanage(
///   ConfigBuilder.create()
///     .withEnvironmentToken('mob_your_token_here')
///     .build(),
/// );
///
/// // Check a flag
/// final flag = await zenmanage.flags().single('new-dashboard');
/// if (flag.isEnabled()) {
///   showNewDashboard();
/// }
///
/// // Check a flag with context
/// final userContext = Context.user(id: 'user123', name: 'John');
/// final betaAccess = await zenmanage.flags()
///   .withContext(userContext)
///   .single('beta-program');
///
/// if (betaAccess.isEnabled()) {
///   enableBetaFeatures();
/// }
/// ```
class Zenmanage {
  /// Creates a Zenmanage SDK instance
  Zenmanage(Config config)
      : _config = config,
        _flagManager = _createFlagManager(config);

  final Config _config;
  final FlagManager _flagManager;

  /// Returns the flag manager for evaluating flags
  FlagManager flags() => _flagManager;

  /// Returns the current cache backend name
  String get cacheBackendName => _config.cache.backendName;

  /// Initializes the SDK asynchronously by prefetching rules.
  ///
  /// Use this during app startup to avoid first-render latency when checking flags.
  Future<void> initialize({List<Context>? contexts}) async {
    await _flagManager.prefetch(contexts: contexts);
  }

  /// Clears all cached rules
  Future<void> clearCache() async {
    await _flagManager.clearCache();
  }

  /// Static factory for creating from configuration
  static FlagManager _createFlagManager(Config config) {
    final apiClient = ApiClient(
      environmentToken: config.environmentToken,
      apiEndpoint: config.apiEndpoint,
      enableUsageReporting: config.enableUsageReporting,
      sdkVersion: config.sdkVersion,
      clientAgent: config.clientAgent,
      requestTimeout: config.requestTimeout,
      logger: config.logger,
    );

    final ruleEngine = RuleEngine();

    return FlagManager(
      apiClient: apiClient,
      cache: config.cache,
      ruleEngine: ruleEngine,
      cacheTtl: config.cacheTtl,
    );
  }
}
