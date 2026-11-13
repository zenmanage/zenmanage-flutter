// Runs the SDK on a real target (device, simulator, emulator or desktop
// window) and checks the two things unit tests on the Dart VM can't:
//
//  * flags load over real HTTP, through the platform's own network stack
//  * `SharedPreferencesCache` writes to the platform's own storage and reads
//    it back after a restart
//
// The app starts its own rules server on the loopback address, so the test
// needs no network access and no Zenmanage token. Run it from `example/`:
//
//     flutter test integration_test -d <device id>
//
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenmanage/zenmanage.dart';
import 'package:zenmanage_example/main.dart' show HomePage;

const _token = 'mob_integration_test_token';
const _prefsKey = 'zenmanage_rules';

/// A stand-in for the Zenmanage API and CDN, listening on the loopback
/// address.
class _RulesServer {
  _RulesServer._(this._server, this.endpoint);

  final HttpServer _server;

  /// Base URL the SDK is pointed at.
  final String endpoint;

  /// Number of `GET /v1/flag-json` requests served.
  int metadataRequests = 0;

  /// Value of the `X-ZEN-API-KEY` header on the last metadata request.
  String? lastApiKey;

  /// The rules document the CDN path serves.
  Map<String, dynamic> rules = {
    'flags': {
      'new-dashboard': {'value': true, 'type': 'boolean'},
      'welcome-message': {'value': 'Hello from the rules', 'type': 'string'},
      'max-items': {'value': 25, 'type': 'number'},
    },
  };

  static Future<_RulesServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = 'http://${server.address.address}:${server.port}';
    final instance = _RulesServer._(server, endpoint);
    server.listen(instance._handle);
    return instance;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;

    if (request.uri.path == '/v1/flag-json') {
      metadataRequests++;
      lastApiKey = request.headers.value('X-ZEN-API-KEY');
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({
        'data': {'cdn': endpoint, 'path': '/rules.json'},
      }));
    } else if (request.uri.path == '/rules.json') {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(rules));
    } else {
      // Usage reports, and anything else the SDK sends.
      response.statusCode = 200;
    }

    await response.close();
  }

  Future<void> stop() => _server.close(force: true);
}

Zenmanage _buildSdk(String endpoint, Cache cache) => Zenmanage(
      ConfigBuilder.create()
          .withEnvironmentToken(_token)
          .withApiEndpoint(endpoint)
          .withCache(cache)
          .withUsageReporting(false)
          .withRequestTimeout(const Duration(seconds: 5))
          .build(),
    );

/// Drops the cached [SharedPreferences] instance, so the next
/// `getInstance()` reads the platform's storage again, as a fresh launch of
/// the app would.
void _simulateRestart() {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.resetStatic();
}

Future<void> _clearStoredRules() async {
  _simulateRestart();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_prefsKey);
  _simulateRestart();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _RulesServer server;

  setUp(() async {
    // A device keeps its storage between runs; start from nothing.
    await _clearStoredRules();
    server = await _RulesServer.start();
  });

  tearDown(() async {
    await server.stop();
    await _clearStoredRules();
  });

  group('flags load on this target', () {
    testWidgets('boolean, string and number flags come from the rules server',
        (tester) async {
      final sdk = _buildSdk(server.endpoint, InMemoryCache());

      final enabled =
          await sdk.flags().single('new-dashboard', defaultValue: false);
      final message =
          await sdk.flags().single('welcome-message', defaultValue: 'default');
      final maxItems = await sdk.flags().single('max-items', defaultValue: 0);

      expect(enabled.isEnabled(), isTrue);
      expect(message.asString(), 'Hello from the rules');
      expect(maxItems.getValue(), 25);
      expect(server.lastApiKey, _token);
    });

    testWidgets('an unknown flag returns the default', (tester) async {
      final sdk = _buildSdk(server.endpoint, InMemoryCache());

      final flag = await sdk.flags().single('no-such-flag', defaultValue: true);

      expect(flag.isEnabled(), isTrue);
    });

    testWidgets('ZenmanageInitializer and ZenmanageFlagBuilder render a flag',
        (tester) async {
      final sdk = _buildSdk(server.endpoint, InMemoryCache());

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageInitializer(
            zenmanage: sdk,
            loadingBuilder: (_) => const Text('loading'),
            errorBuilder: (_, error, __) => Text('failed: $error'),
            child: Scaffold(
              body: ZenmanageFlagBuilder(
                flagKey: 'welcome-message',
                defaultValue: 'default',
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Text('loading flag');
                  }
                  return Text('flag: ${snapshot.data?.asString()}');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('flag: Hello from the rules'), findsOneWidget);
      expect(server.metadataRequests, 1);
    });

    testWidgets('the example HomePage reads the flag from the provider',
        (tester) async {
      final sdk = _buildSdk(server.endpoint, InMemoryCache());

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageInitializer(
            zenmanage: sdk,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('new-dashboard is enabled'), findsOneWidget);
    });
  });

  group('SharedPreferencesCache on this target', () {
    testWidgets('writes the rules to platform storage', (tester) async {
      final cache = SharedPreferencesCache();
      await cache.initialize();
      final sdk = _buildSdk(server.endpoint, cache);

      await sdk.initialize();

      // Read it back the way a new launch would.
      _simulateRestart();
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      expect(stored, isNotNull);
      expect(jsonDecode(stored!), server.rules);
    });

    testWidgets('keeps the rules across a restart when the API is unreachable',
        (tester) async {
      // First launch, online: rules are fetched and cached.
      final firstCache = SharedPreferencesCache();
      await firstCache.initialize();
      final firstRun = _buildSdk(server.endpoint, firstCache);
      await firstRun.initialize();

      // The app is closed and the API goes away.
      final deadEndpoint = server.endpoint;
      await server.stop();
      _simulateRestart();

      // Second launch, offline, nothing in memory: the only source of rules
      // is the platform storage.
      final secondCache = SharedPreferencesCache();
      await secondCache.initialize();
      final secondRun = _buildSdk(deadEndpoint, secondCache);

      final enabled =
          await secondRun.flags().single('new-dashboard', defaultValue: false);
      final message = await secondRun
          .flags()
          .single('welcome-message', defaultValue: 'default');

      expect(enabled.isEnabled(), isTrue);
      expect(message.asString(), 'Hello from the rules');

      // Restart the server for tearDown.
      server = await _RulesServer.start();
    });

    testWidgets('without cached rules the same offline launch gets defaults',
        (tester) async {
      // The control for the test above: it proves that test only passes
      // because of the cache.
      final endpoint = server.endpoint;
      await server.stop();

      final cache = SharedPreferencesCache();
      await cache.initialize();
      final sdk = _buildSdk(endpoint, cache);

      final flag =
          await sdk.flags().single('new-dashboard', defaultValue: false);

      expect(flag.isEnabled(), isFalse);

      server = await _RulesServer.start();
    });

    testWidgets('clearCache removes the stored rules', (tester) async {
      final cache = SharedPreferencesCache();
      await cache.initialize();
      final sdk = _buildSdk(server.endpoint, cache);
      await sdk.initialize();

      await sdk.clearCache();

      _simulateRestart();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(_prefsKey), isFalse);
    });
  });
}
