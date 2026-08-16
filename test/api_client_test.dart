import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/src/api_client.dart';
import 'package:zenmanage/src/context/context.dart';
import 'package:zenmanage/src/exceptions/exceptions.dart';

void main() {
  group('ApiClient.fetchRules', () {
    late HttpServer server;
    late String endpoint;
    late List<Uri> requestedUris;
    late void Function(HttpRequest request) handler;

    setUp(() async {
      requestedUris = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      endpoint = 'http://${server.address.address}:${server.port}';

      server.listen((request) async {
        requestedUris.add(request.uri);
        handler(request);
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    Future<void> respondJson(
      HttpRequest request,
      int statusCode,
      Object body,
    ) async {
      request.response.statusCode = statusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    }

    test('fetches rules via the two-step CDN protocol', () async {
      handler = (request) {
        if (request.uri.path == '/v1/flag-json') {
          respondJson(request, 200, {
            'data': {'cdn': endpoint, 'path': '/rules.json'},
          });
        } else if (request.uri.path == '/rules.json') {
          respondJson(request, 200, {
            'flags': {'test': true},
          });
        }
      };

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);
      final result = await client.fetchRules();

      expect(result['rules'], contains('"test":true'));
      expect(requestedUris.map((u) => u.path), contains('/v1/flag-json'));
      expect(requestedUris.map((u) => u.path), contains('/rules.json'));
    });

    test('sends the API key header on the metadata request', () async {
      String? seenApiKey;
      handler = (request) {
        if (request.uri.path == '/v1/flag-json') {
          seenApiKey = request.headers.value('X-ZEN-API-KEY');
          respondJson(request, 200, {
            'data': {'cdn': endpoint, 'path': '/rules.json'},
          });
        } else {
          respondJson(request, 200, {'flags': <String, dynamic>{}});
        }
      };

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);
      await client.fetchRules();

      expect(seenApiKey, equals('mob_test'));
    });

    test('throws ConfigurationException for an invalid token', () async {
      final client = ApiClient(environmentToken: 'bad_token', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('throws ApiException when metadata request is unauthorized', () async {
      handler = (request) => respondJson(request, 401, {'error': 'unauthorized'});

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws ApiException when metadata request is forbidden', () async {
      handler = (request) => respondJson(request, 403, {'error': 'forbidden'});

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('throws ApiException when metadata request fails with another status', () async {
      handler = (request) => respondJson(request, 500, {'error': 'boom'});

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('throws ApiException when metadata response is missing the data field', () async {
      handler = (request) => respondJson(request, 200, {'nope': true});

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException when metadata response is missing cdn/path', () async {
      handler = (request) => respondJson(request, 200, {
            'data': {'cdn': null, 'path': null},
          });

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException when the CDN request fails', () async {
      handler = (request) {
        if (request.uri.path == '/v1/flag-json') {
          respondJson(request, 200, {
            'data': {'cdn': endpoint, 'path': '/rules.json'},
          });
        } else {
          respondJson(request, 500, {'error': 'cdn down'});
        }
      };

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('wraps unexpected errors in ApiException', () async {
      handler = (request) {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write('not valid json');
        request.response.close();
      };

      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await expectLater(
        client.fetchRules(),
        throwsA(isA<ApiException>()),
      );
    });
  });

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
      expect(capturedHeaders.first.value('X-ZEN-DEFAULT-VALUE'), equals('{"new-ui":true}'));
    });

    test('sends a non-boolean default value header', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await client.reportUsage(flagKey: 'num-flag', flagValue: 42, defaultValue: 42);

      expect(capturedHeaders.first.value('X-ZEN-DEFAULT-VALUE'), equals('{"num-flag":42}'));
    });

    test('omits the default value header when not provided', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await client.reportUsage(flagKey: 'new-ui', flagValue: true);

      expect(capturedHeaders.first.value('X-ZEN-DEFAULT-VALUE'), isNull);
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

      expect(capturedHeaders.first.value('X-ZEN-DEFAULT-VALUE'), equals('{"num-flag":42}'));
      expect(
        capturedHeaders.first.value('X-ZEN-CONTEXT'),
        equals('{"type":"user","identifier":"user-1"}'),
      );
      final body = jsonDecode(capturedBodies.first) as Map<String, dynamic>;
      expect(body.containsKey('context'), isFalse);
    });

    test('omits the context header when no context is provided', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await client.reportUsage(flagKey: 'new-ui', flagValue: true);

      expect(capturedHeaders.first.value('X-ZEN-CONTEXT'), isNull);
    });

    test('sends the API key header', () async {
      final client = ApiClient(environmentToken: 'mob_test', apiEndpoint: endpoint);

      await client.reportUsage(flagKey: 'new-ui', flagValue: true);

      expect(capturedHeaders.first.value('X-ZEN-API-KEY'), equals('mob_test'));
      expect(capturedHeaders.first.value('X-API-Key'), isNull);
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
