/// Configuration builder for easy SDK setup
library zenmanage.config_builder;

import 'config.dart';
import '../cache/cache.dart';
import '../cache/in_memory_cache.dart';
import '../exceptions/exceptions.dart';

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
  String _sdkVersion = '1.0.0';
  String? _clientAgent;

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

    if (!token.startsWith('mob_') &&
        !token.startsWith('srv_') &&
        !token.startsWith('cli_')) {
      throw ConfigurationException(
        'Invalid environment token. Expected a token starting with mob_, srv_, or cli_. '
        'Get your token from https://zenmanage.com',
      );
    }

    final cache = _cache ?? InMemoryCache();

    return Config(
      environmentToken: token,
      cache: cache,
      apiEndpoint: _apiEndpoint,
      cacheTtl: _cacheTtl,
      enableUsageReporting: _enableUsageReporting,
      sdkVersion: _sdkVersion,
      clientAgent: _clientAgent,
    );
  }
}
