/// SDK configuration model
library zenmanage.config;

import '../cache/cache.dart';
import '../logging/logger.dart';
import '../version.dart';

/// Default for [Config.requestTimeout], shared with the other Zenmanage SDKs.
const Duration defaultRequestTimeout = Duration(seconds: 10);

/// Configuration for the Zenmanage SDK
class Config {
  /// Creates a configuration instance
  Config({
    required this.environmentToken,
    required this.cache,
    this.apiEndpoint = 'https://api.zenmanage.com',
    this.cacheTtl = 3600,
    this.enableUsageReporting = true,
    this.sdkVersion = zenmanageSdkVersion,
    this.clientAgent,
    this.requestTimeout = defaultRequestTimeout,
    this.logger = const NullLogger(),
  });

  /// The environment token: a mobile key (mob_) or client key (cli_)
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

  /// How long a rules request may wait before it fails (and is retried).
  ///
  /// Usage reports use the smaller of this and 5 seconds.
  final Duration requestTimeout;

  /// Receives SDK diagnostics. Defaults to a logger that discards everything.
  final ZenmanageLogger logger;
}
