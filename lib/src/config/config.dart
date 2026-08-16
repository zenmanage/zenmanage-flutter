/// SDK configuration model
library zenmanage.config;

import '../cache/cache.dart';

/// Configuration for the Zenmanage SDK
class Config {
  /// Creates a configuration instance
  Config({
    required this.environmentToken,
    required this.cache,
    this.apiEndpoint = 'https://api.zenmanage.com',
    this.cacheTtl = 3600,
    this.enableUsageReporting = true,
    this.sdkVersion = '1.0.0',
    this.clientAgent,
  });

  /// The environment token (mob_, srv_, or cli_ prefix)
  final String environmentToken;

  /// The cache implementation to use
  final Cache cache;

  /// The API endpoint URL
  final String apiEndpoint;

  /// How long to cache rules (in seconds)
  final int cacheTtl;

  /// Whether to report flag usage to the API
  final bool enableUsageReporting;

  /// SDK version for user agent
  final String sdkVersion;

  /// Optional override for the X-ZEN-CLIENT-AGENT header value
  final String? clientAgent;
}
