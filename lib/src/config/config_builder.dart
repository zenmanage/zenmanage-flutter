/// Configuration builder for easy SDK setup
library;

import 'config.dart';
import 'environment_token.dart';
import '../cache/cache.dart';
import '../cache/in_memory_cache.dart';
import '../exceptions/exceptions.dart';
import '../logging/logger.dart';
import '../version.dart';

/// Builder for creating Zenmanage configuration
///
/// Use this to easily create a config with fluent API:
/// ```dart
/// final config = ConfigBuilder.create()
///   .withEnvironmentToken('mob_your_token_here')
///   .withCache(InMemoryCache())
///   .build();
/// ```
class ConfigBuilder {
  String? _environmentToken;
  Cache? _cache;
  String _apiEndpoint = 'https://api.zenmanage.com';
  int _cacheTtl = 3600;
  bool _enableUsageReporting = true;
  String _sdkVersion = zenmanageSdkVersion;
  String? _clientAgent;
  Duration _requestTimeout = defaultRequestTimeout;
  ZenmanageLogger _logger = const NullLogger();

  /// Creates a new config builder
  static ConfigBuilder create() => ConfigBuilder();

  /// Sets the environment token
  ConfigBuilder withEnvironmentToken(String token) {
    _environmentToken = token;
    return this;
  }

  /// Sets the cache backend
  ConfigBuilder withCache(Cache cache) {
    _cache = cache;
    return this;
  }

  /// Sets the API endpoint
  ConfigBuilder withApiEndpoint(String endpoint) {
    _apiEndpoint = endpoint;
    return this;
  }

  /// Sets the cache TTL in seconds
  ConfigBuilder withCacheTtl(int ttl) {
    _cacheTtl = ttl;
    return this;
  }

  /// Enables or disables usage reporting
  ConfigBuilder withUsageReporting(bool enabled) {
    _enableUsageReporting = enabled;
    return this;
  }

  /// Sets the SDK version (for user agent)
  ConfigBuilder withSdkVersion(String version) {
    _sdkVersion = version;
    return this;
  }

  /// Overrides the client agent sent in the X-ZEN-CLIENT-AGENT header.
  ConfigBuilder withClientAgent(String agent) {
    _clientAgent = agent;
    return this;
  }

  /// Sets how long a rules request may wait before it fails (default 10
  /// seconds, the same as the other Zenmanage SDKs).
  ///
  /// Usage reports are capped at 5 seconds regardless.
  ///
  /// Throws [ArgumentError] if [timeout] is zero or negative.
  ConfigBuilder withRequestTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be greater than zero');
    }
    _requestTimeout = timeout;
    return this;
  }

  /// Routes SDK diagnostics (fetch attempts, retries, failures) to [logger].
  ///
  /// Nothing is logged by default.
  ConfigBuilder withLogger(ZenmanageLogger logger) {
    _logger = logger;
    return this;
  }

  /// Builds the configuration
  ///
  /// Throws [ConfigurationException] if required fields are missing
  Config build() {
    final token = _environmentToken;
    if (token == null || token.isEmpty) {
      throw ConfigurationException(
        'Environment token is required. Get your token from https://zenmanage.com',
      );
    }

    validateEnvironmentToken(token);

    final cache = _cache ?? InMemoryCache();

    return Config(
      environmentToken: token,
      cache: cache,
      apiEndpoint: _apiEndpoint,
      cacheTtl: _cacheTtl,
      enableUsageReporting: _enableUsageReporting,
      sdkVersion: _sdkVersion,
      clientAgent: _clientAgent,
      requestTimeout: _requestTimeout,
      logger: _logger,
    );
  }
}
