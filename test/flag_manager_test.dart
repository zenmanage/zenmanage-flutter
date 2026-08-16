import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/src/api_client.dart';
import 'package:zenmanage/src/cache/null_cache.dart';
import 'package:zenmanage/src/exceptions/exceptions.dart';
import 'package:zenmanage/src/flag/flag_manager.dart';
import 'package:zenmanage/src/rule_engine.dart';

void main() {
  group('FlagManager.single default value reporting', () {
    late HttpServer server;
    late String endpoint;
    late List<HttpHeaders> usageHeaders;

    setUp(() async {
      usageHeaders = [];
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
          request.response.write(jsonEncode({'flags': <String, dynamic>{}}));
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
  });
}
