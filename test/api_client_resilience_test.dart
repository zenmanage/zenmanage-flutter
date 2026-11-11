import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';
import 'package:zenmanage/src/api_client.dart';

class _LogEntry {
  _LogEntry(this.level, this.message, this.metadata);

  final String level;
  final String message;
  final Map<String, Object?>? metadata;
}

class _RecordingLogger implements ZenmanageLogger {
  final List<_LogEntry> entries = [];

  Iterable<_LogEntry> where(String level) => entries.where((e) => e.level == level);

  @override
  void debug(String message, [Map<String, Object?>? metadata]) =>
      entries.add(_LogEntry('debug', message, metadata));

  @override
  void info(String message, [Map<String, Object?>? metadata]) =>
      entries.add(_LogEntry('info', message, metadata));

  @override
  void warn(String message, [Map<String, Object?>? metadata]) =>
      entries.add(_LogEntry('warn', message, metadata));

  @override
  void error(String message, [Map<String, Object?>? metadata]) =>
      entries.add(_LogEntry('error', message, metadata));
}

void main() {
  late HttpServer server;
  late String endpoint;
  late List<HttpRequest> requests;
  late FutureOr<void> Function(HttpRequest request) handler;

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    endpoint = 'http://${server.address.address}:${server.port}';
    server.listen((request) async {
      requests.add(request);
      await handler(request);
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  Future<void> respondJson(HttpRequest request, int statusCode, Object body) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> respondWithRules(HttpRequest request) async {
    if (request.uri.path == '/v1/flag-json') {
      await respondJson(request, 200, {
        'data': {'cdn': endpoint, 'path': '/rules.json'},
      });
    } else {
      await respondJson(request, 200, {'flags': <String, dynamic>{}});
    }
  }

  int metadataRequests() => requests.where((r) => r.uri.path == '/v1/flag-json').length;

  ApiClient clientWith({
    Duration requestTimeout = const Duration(seconds: 10),
    Duration retryBaseDelay = const Duration(milliseconds: 1),
    ZenmanageLogger? logger,
    String? clientAgent,
    String? sdkVersion,
  }) =>
      ApiClient(
        environmentToken: 'mob_test',
        apiEndpoint: endpoint,
        requestTimeout: requestTimeout,
        retryBaseDelay: retryBaseDelay,
        logger: logger,
        clientAgent: clientAgent,
        sdkVersion: sdkVersion,
      );

  group('retries', () {
    test('retries a failed fetch and succeeds on the third attempt', () async {
      handler = (request) async {
        if (request.uri.path == '/v1/flag-json' && metadataRequests() < 3) {
          await respondJson(request, 500, {'error': 'boom'});
        } else {
          await respondWithRules(request);
        }
      };

      final result = await clientWith().fetchRules();

      expect(result['rules'], contains('flags'));
      expect(metadataRequests(), equals(3));
    });

    test('gives up after three attempts and reports the last status code', () async {
      handler = (request) => respondJson(request, 503, {'error': 'down'});

      await expectLater(
        clientWith().fetchRules(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.message, 'message', contains('after 3 attempts')),
        ),
      );
      expect(metadataRequests(), equals(3));
    });

    test('retries when the CDN request fails', () async {
      var cdnHits = 0;
      handler = (request) async {
        if (request.uri.path == '/v1/flag-json') {
          await respondJson(request, 200, {
            'data': {'cdn': endpoint, 'path': '/rules.json'},
          });
        } else {
          cdnHits++;
          if (cdnHits < 2) {
            await respondJson(request, 502, {'error': 'cdn'});
          } else {
            await respondJson(request, 200, {'flags': <String, dynamic>{}});
          }
        }
      };

      final result = await clientWith().fetchRules();

      expect(result['rules'], isNotEmpty);
      expect(cdnHits, equals(2));
    });

    test('does not retry a rejected token (401)', () async {
      handler = (request) => respondJson(request, 401, {'error': 'nope'});

      await expectLater(
        clientWith().fetchRules(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      expect(metadataRequests(), equals(1));
    });

    test('does not retry a forbidden token (403)', () async {
      handler = (request) => respondJson(request, 403, {'error': 'nope'});

      await expectLater(
        clientWith().fetchRules(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
      expect(metadataRequests(), equals(1));
    });

    test('does not retry a malformed token (nothing is sent)', () async {
      handler = respondWithRules;
      final client = ApiClient(
        environmentToken: 'not-a-token',
        apiEndpoint: endpoint,
        retryBaseDelay: const Duration(milliseconds: 1),
      );

      await expectLater(client.fetchRules(), throwsA(isA<ConfigurationException>()));
      expect(requests, isEmpty);
    });

    test('doubles the delay between attempts (100ms, 200ms by default)', () async {
      handler = (request) => respondJson(request, 500, {'error': 'boom'});
      final logger = _RecordingLogger();

      await expectLater(
        ApiClient(
          environmentToken: 'mob_test',
          apiEndpoint: endpoint,
          logger: logger,
        ).fetchRules(),
        throwsA(isA<ApiException>()),
      );

      final delays = logger
          .where('debug')
          .where((e) => e.message == 'Retrying rules fetch')
          .map((e) => e.metadata!['delayMs'])
          .toList();
      expect(delays, equals([100, 200]));
    });
  });

  group('timeouts', () {
    test('fails with a timeout error when the API never answers', () async {
      handler = (request) async {
        // Never respond.
        await Completer<void>().future;
      };

      final stopwatch = Stopwatch()..start();
      await expectLater(
        clientWith(requestTimeout: const Duration(milliseconds: 150)).fetchRules(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', contains('after 3 attempts'))
              .having((e) => e.message, 'message', contains('timeout after 150 ms')),
        ),
      );
      stopwatch.stop();

      // Three 150ms attempts plus tiny backoffs: well under the old 30s
      // timeout, proving the configured value is what is applied.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(metadataRequests(), equals(3));
    });

    test('defaults to a 10 second request timeout', () {
      expect(defaultRequestTimeout, equals(const Duration(seconds: 10)));
      expect(
        ApiClient(environmentToken: 'mob_test').requestTimeout,
        equals(const Duration(seconds: 10)),
      );
    });

    test('caps usage reports at 5 seconds', () {
      expect(ApiClient.usageReportTimeout, equals(const Duration(seconds: 5)));
    });

    test('a usage report that hangs is abandoned at the configured timeout', () async {
      handler = (request) async {
        await Completer<void>().future;
      };

      final stopwatch = Stopwatch()..start();
      await clientWith(requestTimeout: const Duration(milliseconds: 150))
          .reportUsage(flagKey: 'k', flagValue: true);
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)));
    });
  });

  group('logging', () {
    test('logs each failed attempt and the eventual success', () async {
      final logger = _RecordingLogger();
      handler = (request) async {
        if (request.uri.path == '/v1/flag-json' && metadataRequests() < 2) {
          await respondJson(request, 500, {'error': 'boom'});
        } else {
          await respondWithRules(request);
        }
      };

      await clientWith(logger: logger).fetchRules();

      final warns = logger.where('warn').toList();
      expect(warns, hasLength(1));
      expect(warns.single.message, equals('Failed to fetch rules'));
      expect(warns.single.metadata!['attempt'], equals(1));
      expect(warns.single.metadata!['statusCode'], equals(500));

      final infos = logger.where('info').toList();
      expect(infos, hasLength(1));
      expect(infos.single.metadata!['attempt'], equals(2));
    });

    test('logs a failed usage report instead of throwing', () async {
      final logger = _RecordingLogger();
      final client = ApiClient(
        environmentToken: 'mob_test',
        // Nothing is listening here, so the request fails immediately.
        apiEndpoint: 'http://127.0.0.1:1',
        logger: logger,
      );

      await client.reportUsage(flagKey: 'my-flag', flagValue: true);

      final failures =
          logger.where('debug').where((e) => e.message == 'Failed to report flag usage');
      expect(failures, hasLength(1));
      expect(failures.single.metadata!['flagKey'], equals('my-flag'));
    });

    test('NullLogger discards every level', () {
      const logger = NullLogger();
      logger
        ..debug('d')
        ..info('i', {'a': 1})
        ..warn('w')
        ..error('e', {'b': 2});
    });
  });

  group('client agent', () {
    test('sends zenmanage-flutter/<sdk version> on the flag-json request', () async {
      String? agent;
      handler = (request) async {
        if (request.uri.path == '/v1/flag-json') {
          agent = request.headers.value('X-ZEN-CLIENT-AGENT');
        }
        await respondWithRules(request);
      };

      await clientWith().fetchRules();

      expect(agent, equals('zenmanage-flutter/$zenmanageSdkVersion'));
    });

    test('sends the same agent on usage reports', () async {
      String? agent;
      handler = (request) async {
        agent = request.headers.value('X-ZEN-CLIENT-AGENT');
        request.response.statusCode = 200;
        await request.response.close();
      };

      await clientWith().reportUsage(flagKey: 'k', flagValue: true);

      expect(agent, equals('zenmanage-flutter/$zenmanageSdkVersion'));
    });

    test('the agent family matches the API allow-list format (family/version)', () {
      const agent = 'zenmanage-flutter/$zenmanageSdkVersion';
      final parts = agent.split('/');
      expect(parts, hasLength(2));
      expect(parts.first, equals('zenmanage-flutter'));
      expect(parts.last, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('honours withClientAgent and withSdkVersion overrides', () async {
      String? agent;
      handler = (request) async {
        if (request.uri.path == '/v1/flag-json') {
          agent = request.headers.value('X-ZEN-CLIENT-AGENT');
        }
        await respondWithRules(request);
      };

      await clientWith(clientAgent: 'zenmanage-flutter-test', sdkVersion: '9.9.9').fetchRules();

      expect(agent, equals('zenmanage-flutter-test/9.9.9'));
    });
  });
}
