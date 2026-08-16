/// API client for fetching rules from Zenmanage API
library zenmanage.api_client;

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'context/context.dart';
import 'exceptions/exceptions.dart';

/// Fetches rules from the Zenmanage API
class ApiClient {
  /// Creates an API client
  ApiClient({
    required String environmentToken,
    String? apiEndpoint,
    this.enableUsageReporting = true,
    String? sdkVersion,
    String? clientAgent,
  })  : _environmentToken = environmentToken,
        _apiEndpoint = apiEndpoint ?? 'https://api.zenmanage.com',
        _sdkVersion = sdkVersion ?? '1.0.0',
        _clientAgent = clientAgent ?? 'zenmanage-flutter';

  final String _environmentToken;
  final String _apiEndpoint;
  final String _sdkVersion;
  final String _clientAgent;
  final bool enableUsageReporting;

  /// Fetches rules from the API using the two-step CDN protocol.
  ///
  /// Step 1: GET /v1/flag-json to get the CDN URL.
  /// Step 2: GET the CDN URL to fetch the rules JSON.
  ///
  /// Throws [ConfigurationException] if token is invalid
  /// Throws [ApiException] if the request fails
  Future<Map<String, dynamic>> fetchRules({
    List<Context>? contexts,
  }) async {
    _validateToken();

    try {
      // Step 1: Get CDN URL from metadata endpoint
      final metadataUrl = Uri.parse('$_apiEndpoint/v1/flag-json');
      final metadataResponse = await http.get(
        metadataUrl,
        headers: _buildHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw ApiException('Request timeout after 30 seconds');
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
        const Duration(seconds: 30),
        onTimeout: () {
          throw ApiException('CDN request timeout after 30 seconds');
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
  /// `X-Default-Value` header so it can be persisted and shown on the flag
  /// detail page.
  ///
  /// This is a best-effort operation and failures are logged silently
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

      if (defaultValue != null) {
        try {
          headers['X-Default-Value'] = jsonEncode({flagKey: defaultValue});
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
          if (context != null) 'context': context.toJson(),
        }),
      ).timeout(
        const Duration(seconds: 5),
      );
      // Silently ignore errors in reporting
    } catch (_) {
      // Ignore errors in background reporting
    }
  }

  /// Validates the environment token format
  void _validateToken() {
    if (!_environmentToken.startsWith('mob_') &&
        !_environmentToken.startsWith('srv_') &&
        !_environmentToken.startsWith('cli_')) {
      throw ConfigurationException(
        'Invalid environment token. Expected a token starting with mob_, srv_, or cli_. '
        'Get your token from https://zenmanage.com',
      );
    }
  }

  /// Builds request headers
  Map<String, String> _buildHeaders() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-API-Key': _environmentToken,
        'X-ZEN-CLIENT-AGENT': '$_clientAgent/$_sdkVersion',
      };
}

