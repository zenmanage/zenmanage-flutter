/// API client for fetching rules from Zenmanage API
library zenmanage.api_client;

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config/config.dart';
import 'config/environment_token.dart';
import 'context/context.dart';
import 'exceptions/exceptions.dart';
import 'logging/logger.dart';
import 'version.dart';

/// Fetches rules from the Zenmanage API
class ApiClient {
  /// Creates an API client
  ApiClient({
    required String environmentToken,
    String? apiEndpoint,
    this.enableUsageReporting = true,
    String? sdkVersion,
    String? clientAgent,
    this.requestTimeout = defaultRequestTimeout,
    ZenmanageLogger? logger,
    this.retryBaseDelay = defaultRetryBaseDelay,
  })  : _environmentToken = environmentToken,
        _apiEndpoint = apiEndpoint ?? 'https://api.zenmanage.com',
        _sdkVersion = sdkVersion ?? zenmanageSdkVersion,
        _clientAgent = clientAgent ?? 'zenmanage-flutter',
        _logger = logger ?? const NullLogger();

  /// How many times a rules fetch is attempted before giving up. Shared with
  /// the other Zenmanage SDKs.
  static const int maxAttempts = 3;

  /// Delay before the second attempt; each later attempt doubles it
  /// (100ms, then 200ms). Shared with the other Zenmanage SDKs.
  static const Duration defaultRetryBaseDelay = Duration(milliseconds: 100);

  /// Upper bound for a fire-and-forget usage report.
  static const Duration usageReportTimeout = Duration(seconds: 5);

  final String _environmentToken;
  final String _apiEndpoint;
  final String _sdkVersion;
  final String _clientAgent;
  final ZenmanageLogger _logger;
  final bool enableUsageReporting;

  /// How long each rules request may wait before it fails.
  final Duration requestTimeout;

  /// Delay before the second rules attempt (doubles for each later attempt).
  final Duration retryBaseDelay;

  /// Fetches rules from the API using the two-step CDN protocol.
  ///
  /// Step 1: GET /v1/flag-json to get the CDN URL.
  /// Step 2: GET the CDN URL to fetch the rules JSON.
  ///
  /// Each failed attempt is retried (up to [maxAttempts] in total, with
  /// exponential backoff). A rejected token (HTTP 401 or 403) is not retried,
  /// since another attempt with the same token cannot succeed.
  ///
  /// Throws [ConfigurationException] if token is invalid
  /// Throws [ApiException] if the request fails
  Future<Map<String, dynamic>> fetchRules({
    List<Context>? contexts,
  }) async {
    _validateToken();

    ApiException? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        final delay = retryBaseDelay * (1 << (attempt - 2));
        _logger.debug('Retrying rules fetch', {
          'attempt': attempt,
          'delayMs': delay.inMilliseconds,
        });
        await Future<void>.delayed(delay);
      }

      try {
        final rules = await _fetchRulesOnce();
        _logger.info('Successfully fetched rules', {'attempt': attempt});
        return rules;
      } on ApiException catch (e) {
        lastError = e;
        _logger.warn('Failed to fetch rules', {
          'attempt': attempt,
          'error': e.message,
          if (e.statusCode != null) 'statusCode': e.statusCode,
        });

        if (_isRejectedToken(e)) {
          rethrow;
        }
      }
    }

    final error = lastError!;
    throw ApiException(
      'Failed to fetch rules after $maxAttempts attempts: ${error.message}',
      statusCode: error.statusCode,
      originalError: error.originalError ?? error,
    );
  }

  bool _isRejectedToken(ApiException e) =>
      e.statusCode == 401 || e.statusCode == 403;

  Future<Map<String, dynamic>> _fetchRulesOnce() async {
    try {
      // Step 1: Get CDN URL from metadata endpoint
      final metadataUrl = Uri.parse('$_apiEndpoint/v1/flag-json');
      final metadataResponse = await http.get(
        metadataUrl,
        headers: _buildHeaders(),
      ).timeout(
        requestTimeout,
        onTimeout: () {
          throw ApiException(
            'Request timeout after ${_describe(requestTimeout)}',
          );
        },
      );

      if (metadataResponse.statusCode == 401 || metadataResponse.statusCode == 403) {
        throw ApiException(
          'Invalid or expired environment token',
          statusCode: metadataResponse.statusCode,
        );
      }

      if (metadataResponse.statusCode != 200) {
        throw ApiException(
          'API metadata request failed: ${metadataResponse.body}',
          statusCode: metadataResponse.statusCode,
        );
      }

      final metadataJson = jsonDecode(metadataResponse.body) as Map<String, dynamic>;
      final data = metadataJson['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw ApiException('API response missing data field');
      }
      final cdn = data['cdn'] as String?;
      final path = data['path'] as String?;
      if (cdn == null || path == null) {
        throw ApiException('API response missing cdn or path field');
      }

      // Step 2: Fetch rules from CDN
      final cdnUrl = Uri.parse('$cdn$path');
      final rulesResponse = await http.get(
        cdnUrl,
        headers: {'Accept': 'application/json'},
      ).timeout(
        requestTimeout,
        onTimeout: () {
          throw ApiException(
            'CDN request timeout after ${_describe(requestTimeout)}',
          );
        },
      );

      if (rulesResponse.statusCode != 200) {
        throw ApiException(
          'CDN request failed with status ${rulesResponse.statusCode}',
          statusCode: rulesResponse.statusCode,
        );
      }

      // Return the rules JSON body as a string under 'rules' key for FlagManager
      return {'rules': rulesResponse.body};
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Failed to fetch rules: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Reports flag usage to the API (if enabled)
  ///
  /// [defaultValue], when provided, is the fallback value the caller used
  /// because the flag couldn't be resolved from rules. It's sent as the
  /// `X-ZEN-DEFAULT-VALUE` header so it can be persisted and shown on the
  /// flag detail page.
  ///
  /// [context], when provided, is sent as the `X-ZEN-CONTEXT` header so the
  /// server can record it — the server only reads context from that header,
  /// not from the request body.
  ///
  /// This is a best-effort operation: it waits at most 5 seconds (or
  /// [requestTimeout], if that is shorter) and failures are only logged.
  Future<void> reportUsage({
    required String flagKey,
    required dynamic flagValue,
    Context? context,
    dynamic defaultValue,
  }) async {
    if (!enableUsageReporting) return;

    try {
      _validateToken();

      final url = Uri.parse('$_apiEndpoint/v1/flags/$flagKey/usage');
      final headers = _buildHeaders();

      if (context != null) {
        try {
          headers['X-ZEN-CONTEXT'] = jsonEncode(context.toJson());
        } catch (_) {
          // Skip the header if the context can't be encoded; still report usage.
        }
      }

      if (defaultValue != null) {
        try {
          headers['X-ZEN-DEFAULT-VALUE'] = jsonEncode({flagKey: defaultValue});
        } catch (_) {
          // Skip the header if the default value can't be encoded; still report usage.
        }
      }

      await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'flagKey': flagKey,
          'flagValue': flagValue,
        }),
      ).timeout(
        requestTimeout < usageReportTimeout ? requestTimeout : usageReportTimeout,
      );
    } catch (e) {
      // Reporting is best-effort: never surface its failures to the caller.
      _logger.debug('Failed to report flag usage', {
        'flagKey': flagKey,
        'error': e.toString(),
      });
    }
  }

  /// Validates the environment token format
  void _validateToken() => validateEnvironmentToken(_environmentToken);

  /// Builds request headers
  Map<String, String> _buildHeaders() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-ZEN-API-KEY': _environmentToken,
        'X-ZEN-CLIENT-AGENT': '$_clientAgent/$_sdkVersion',
      };

  static String _describe(Duration d) => d.inMilliseconds % 1000 == 0
      ? '${d.inSeconds} seconds'
      : '${d.inMilliseconds} ms';
}
