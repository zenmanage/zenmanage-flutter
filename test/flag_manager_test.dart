import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/src/api_client.dart';
import 'package:zenmanage/src/cache/in_memory_cache.dart';
import 'package:zenmanage/src/cache/null_cache.dart';
import 'package:zenmanage/src/cache/cache.dart';
import 'package:zenmanage/src/context/context.dart';
import 'package:zenmanage/src/exceptions/exceptions.dart';
import 'package:zenmanage/src/flag/flag.dart';
import 'package:zenmanage/src/flag/flag_manager.dart';
import 'package:zenmanage/src/rule_engine.dart';

void main() {
  group('FlagManager', () {
    late HttpServer server;
    late String endpoint;
    late Map<String, dynamic> rulesPayload;
    late int metadataRequests;
    late bool failMetadata;

    setUp(() async {
      metadataRequests = 0;
      failMetadata = false;
      rulesPayload = {
        'flags': {
          'new-dashboard': {'value': true, 'type': 'boolean'},
        },
      };
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      endpoint = 'http://${server.address.address}:${server.port}';

      server.listen((request) async {
        if (request.uri.path == '/v1/flag-json') {
          metadataRequests++;
          if (failMetadata) {
            request.response.statusCode = 500;
            await request.response.close();
            return;
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'data': {'cdn': endpoint, 'path': '/rules.json'},
          }));
          await request.response.close();
          return;
        }

        if (request.uri.path == '/rules.json') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(rulesPayload));
          await request.response.close();
          return;
        }

        request.response.statusCode = 200;
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    FlagManager buildManager({Cache? cache, int cacheTtl = 3600}) => FlagManager(
          apiClient: ApiClient(
            environmentToken: 'mob_test',
            apiEndpoint: endpoint,
            enableUsageReporting: false,
          ),
          cache: cache ?? NullCache(),
          ruleEngine: RuleEngine(),
          cacheTtl: cacheTtl,
        );

    test('single returns the evaluated flag when found', () async {
      final manager = buildManager();

      final flag = await manager.single('new-dashboard');

      expect(flag.isEnabled(), isTrue);
    });

    test('all returns every flag from rules', () async {
      rulesPayload = {
        'flags': {
          'a': {'value': true, 'type': 'boolean'},
          'b': {'value': 'control', 'type': 'string'},
        },
      };
      final manager = buildManager();

      final flags = await manager.all();

      expect(flags.map((f) => f.key), containsAll(<String>['a', 'b']));
    });

    test('singleOrDefault returns the resolved flag when found', () async {
      final manager = buildManager();
      final fallback = Flag(key: 'new-dashboard', value: false, type: 'boolean');

      final flag = await manager.singleOrDefault('new-dashboard', fallback);

      expect(flag.isEnabled(), isTrue);
    });

    test('singleOrDefault returns the fallback when resolution throws', () async {
      final manager = buildManager();
      final fallback = Flag(key: 'missing', value: false, type: 'boolean');

      final flag = await manager.singleOrDefault('missing', fallback);

      expect(flag, same(fallback));
    });

    test('withContext, withContexts, and clearContext are chainable', () {
      final manager = buildManager();

      expect(manager.withContext(Context.user(id: 'u1')), same(manager));
      expect(
        manager.withContexts(<Context>[Context.user(id: 'u2')]),
        same(manager),
      );
      expect(manager.clearContext(), same(manager));
    });

    test('prefetch warms the rules cache ahead of first flag access', () async {
      final manager = buildManager();

      await manager.prefetch();
      expect(metadataRequests, equals(1));

      await manager.single('new-dashboard');
      expect(
        metadataRequests,
        equals(1),
        reason: 'a fresh in-TTL cache should not trigger a second fetch',
      );
    });

    test('prefetch applies the supplied contexts for the initial fetch', () async {
      final manager = buildManager();

      await manager.prefetch(contexts: <Context>[Context.user(id: 'u1')]);

      final flag = await manager.single('new-dashboard');
      expect(flag.isEnabled(), isTrue);
    });

    test('rules are re-fetched on every call once the TTL is exhausted', () async {
      final manager = buildManager(cacheTtl: 0);

      await manager.single('new-dashboard');
      await manager.single('new-dashboard');

      expect(metadataRequests, equals(2));
    });

    test('clearCache resets in-memory and persistent cache state', () async {
      final cache = InMemoryCache();
      final manager = buildManager(cache: cache);
      await manager.single('new-dashboard');
      expect(await cache.getRules(), isNotNull);

      await manager.clearCache();

      expect(await cache.getRules(), isNull);
      await manager.single('new-dashboard');
      expect(metadataRequests, equals(2));
    });

    test('falls back to the persistent cache when the API request fails', () async {
      final cache = InMemoryCache();
      await cache.setRules(jsonEncode({
        'flags': {
          'cached-flag': {'value': true, 'type': 'boolean'},
        },
      }));
      failMetadata = true;
      final manager = buildManager(cache: cache);

      final flag = await manager.single('cached-flag');

      expect(flag.isEnabled(), isTrue);
    });

    test('rethrows the API error when there is no cached fallback', () async {
      failMetadata = true;
      final manager = buildManager(cache: NullCache());

      await expectLater(
        manager.single('anything'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('FlagManager.single default value reporting', () {
    late HttpServer server;
    late String endpoint;
    late List<HttpHeaders> usageHeaders;
    late Map<String, dynamic> rulesPayload;

    setUp(() async {
      usageHeaders = [];
      rulesPayload = {'flags': <String, dynamic>{}};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      endpoint = 'http://${server.address.address}:${server.port}';

      server.listen((request) async {
        if (request.uri.path == '/v1/flag-json') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'data': {'cdn': endpoint, 'path': '/rules.json'},
          }));
          await request.response.close();
          return;
        }

        if (request.uri.path == '/rules.json') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(rulesPayload));
          await request.response.close();
          return;
        }

        if (request.uri.path.startsWith('/v1/flags/') && request.uri.path.endsWith('/usage')) {
          usageHeaders.add(request.headers);
        }

        request.response.statusCode = 200;
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    FlagManager buildManager() => FlagManager(
          apiClient: ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint),
          cache: NullCache(),
          ruleEngine: RuleEngine(),
        );

    Future<void> waitForUsageReport() =>
        Future<void>.delayed(const Duration(milliseconds: 100));

    test('falls back to defaultValue and reports it when the flag is missing', () async {
      // NullCache + no seeded rules means the rules payload has no flags.
      final manager = buildManager();

      final flag = await manager.single('missing-flag', defaultValue: true);

      expect(flag.value, isTrue);
      expect(flag.type, equals('boolean'));

      await waitForUsageReport();
      expect(usageHeaders, hasLength(1));
      expect(usageHeaders.first.value('X-ZEN-DEFAULT-VALUE'), equals('{"missing-flag":true}'));
    });

    test('throws FlagNotFoundException when no defaultValue is supplied and flag is missing', () async {
      final manager = buildManager();

      await expectLater(
        manager.single('missing-flag'),
        throwsA(isA<FlagNotFoundException>()),
      );
    });

    test('infers string type for non-bool, non-num default values', () async {
      final manager = buildManager();

      final flag = await manager.single('missing-flag', defaultValue: 'control');

      expect(flag.value, equals('control'));
      expect(flag.type, equals('string'));

      await waitForUsageReport();
      expect(usageHeaders.first.value('X-ZEN-DEFAULT-VALUE'), equals('{"missing-flag":"control"}'));
    });

    test('infers json type for a map default value', () async {
      final manager = buildManager();
      final defaultValue = {'primaryColor': '#000', 'fontSize': 14};

      final flag = await manager.single('missing-flag', defaultValue: defaultValue);

      expect(flag.value, equals(defaultValue));
      expect(flag.type, equals('json'));
      expect(flag.asJson(), equals(defaultValue));

      await waitForUsageReport();
      expect(
        usageHeaders.first.value('X-ZEN-DEFAULT-VALUE'),
        equals(jsonEncode({'missing-flag': defaultValue})),
      );
    });

    test('infers json type for a list default value', () async {
      final manager = buildManager();
      final defaultValue = [1, 2, 3];

      final flag = await manager.single('missing-flag', defaultValue: defaultValue);

      expect(flag.value, equals(defaultValue));
      expect(flag.type, equals('json'));
      expect(flag.asList<int>(), equals(defaultValue));

      await waitForUsageReport();
      expect(
        usageHeaders.first.value('X-ZEN-DEFAULT-VALUE'),
        equals(jsonEncode({'missing-flag': defaultValue})),
      );
    });

    test('reports the default value even when the flag is found', () async {
      rulesPayload = {
        'flags': {
          'new-dashboard': {'value': true, 'type': 'boolean'},
        },
      };
      final manager = buildManager();

      final flag = await manager.single('new-dashboard', defaultValue: false);

      expect(flag.value, isTrue);

      await waitForUsageReport();
      expect(usageHeaders, hasLength(1));
      expect(usageHeaders.first.value('X-ZEN-DEFAULT-VALUE'), equals('{"new-dashboard":false}'));
    });
  });
}
