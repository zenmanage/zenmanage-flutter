import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/src/api_client.dart';
import 'package:zenmanage/src/context/context.dart';

void main() {
  group('ApiClient.reportUsage', () {
    late HttpServer server;
    late String endpoint;
    late List<HttpHeaders> capturedHeaders;
    late List<String> capturedBodies;

    setUp(() async {
      capturedHeaders = [];
      capturedBodies = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      endpoint = 'http://${server.address.address}:${server.port}';

      server.listen((request) async {
        capturedHeaders.add(request.headers);
        capturedBodies.add(await utf8.decoder.bind(request).join());
        request.response.statusCode = 200;
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('sends the default value header', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await client.reportUsage(flagKey: 'new-ui', flagValue: true, defaultValue: true);

      expect(capturedHeaders, hasLength(1));
      expect(capturedHeaders.first.value('X-Default-Value'), equals('{"new-ui":true}'));
    });

    test('sends a non-boolean default value header', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await client.reportUsage(flagKey: 'num-flag', flagValue: 42, defaultValue: 42);

      expect(capturedHeaders.first.value('X-Default-Value'), equals('{"num-flag":42}'));
    });

    test('omits the default value header when not provided', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await client.reportUsage(flagKey: 'new-ui', flagValue: true);

      expect(capturedHeaders.first.value('X-Default-Value'), isNull);
    });

    test('sends both context and default value headers', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);
      final context = Context.user(id: 'user-1');

      await client.reportUsage(
        flagKey: 'num-flag',
        flagValue: 42,
        context: context,
        defaultValue: 42,
      );

      expect(capturedHeaders.first.value('X-Default-Value'), equals('{"num-flag":42}'));
      final body = jsonDecode(capturedBodies.first) as Map<String, dynamic>;
      expect(body['context'], isNotNull);
    });

    test('does not send a request when usage reporting is disabled', () async {
      final client = ApiClient(
        environmentToken: 'mob_test',
        apiEndpoint: endpoint,
        enableUsageReporting: false,
      );

      await client.reportUsage(flagKey: 'new-ui', flagValue: true, defaultValue: true);

      expect(capturedHeaders, isEmpty);
    });
  });
}
