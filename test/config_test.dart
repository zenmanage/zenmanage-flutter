// Test configuration setup
import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';

/// Test setup and utilities
void main() {
  group('Zenmanage Configuration', () {
    test('ConfigBuilder creates valid config with required fields', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .build();

      expect(config.environmentToken, equals('mob_test_token'));
      expect(config.cache, isNotNull);
      expect(config.apiEndpoint, equals('https://api.zenmanage.com'));
      expect(config.cacheTtl, equals(3600));
    });

    test('ConfigBuilder throws exception without token', () {
      expect(
        () => ConfigBuilder.create().build(),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('ConfigBuilder throws exception with invalid token', () {
      expect(
        () => ConfigBuilder.create()
            .withEnvironmentToken('invalid_token')
            .build(),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('ConfigBuilder with custom cache', () {
      final cache = InMemoryCache();
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withCache(cache)
          .build();

      expect(config.cache, equals(cache));
    });

    test('ConfigBuilder with custom API endpoint', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withApiEndpoint('https://custom.example.com')
          .build();

      expect(config.apiEndpoint, equals('https://custom.example.com'));
    });

    test('ConfigBuilder with custom cache TTL', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withCacheTtl(7200)
          .build();

      expect(config.cacheTtl, equals(7200));
    });

    test('ConfigBuilder enables usage reporting by default', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .build();

      expect(config.enableUsageReporting, isTrue);
    });

    test('ConfigBuilder with usage reporting disabled', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withUsageReporting(false)
          .build();

      expect(config.enableUsageReporting, isFalse);
    });

    test('ConfigBuilder with custom SDK version', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withSdkVersion('2.0.0')
          .build();

      expect(config.sdkVersion, equals('2.0.0'));
    });

    test('ConfigBuilder defaults SDK version to the runtime version', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .build();

      expect(config.sdkVersion, equals(zenmanageSdkVersion));
    });

    test('ConfigBuilder with custom client agent', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withClientAgent('my-app/1.0')
          .build();

      expect(config.clientAgent, equals('my-app/1.0'));
    });

    test('ConfigBuilder defaults client agent to null', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .build();

      expect(config.clientAgent, isNull);
    });

    test('ConfigBuilder defaults the request timeout to 10 seconds', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .build();

      expect(config.requestTimeout, equals(const Duration(seconds: 10)));
    });

    test('ConfigBuilder with custom request timeout', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withRequestTimeout(const Duration(seconds: 3))
          .build();

      expect(config.requestTimeout, equals(const Duration(seconds: 3)));
    });

    test('ConfigBuilder rejects a zero or negative request timeout', () {
      final builder = ConfigBuilder.create().withEnvironmentToken('mob_test_token');

      expect(() => builder.withRequestTimeout(Duration.zero), throwsArgumentError);
      expect(
        () => builder.withRequestTimeout(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('ConfigBuilder defaults the logger to a no-op logger', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .build();

      expect(config.logger, isA<NullLogger>());
    });

    test('ConfigBuilder with custom logger', () {
      const logger = NullLogger();
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withLogger(logger)
          .build();

      expect(config.logger, same(logger));
    });

    test('ConfigBuilder rejects srv_ (server) tokens', () {
      expect(
        () => ConfigBuilder.create().withEnvironmentToken('srv_test_token').build(),
        throwsA(
          isA<ConfigurationException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Server keys'), contains('extracted'), contains('mob_'), contains('cli_')),
          ),
        ),
      );
    });

    test('ConfigBuilder rejects a token with an unknown prefix', () {
      expect(
        () => ConfigBuilder.create().withEnvironmentToken('abc_test_token').build(),
        throwsA(
          isA<ConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('mobile key (mob_) or a client key (cli_)'),
          ),
        ),
      );
    });

    test('ConfigBuilder accepts cli_ prefixed tokens', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('cli_test_token')
          .build();

      expect(config.environmentToken, equals('cli_test_token'));
    });

    test('ConfigBuilder throws exception for empty token', () {
      expect(
        () => ConfigBuilder.create().withEnvironmentToken('').build(),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });

  group('Zenmanage Initialization', () {
    test('Zenmanage initializes successfully', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .build();

      final zenmanage = Zenmanage(config);

      expect(zenmanage, isNotNull);
      expect(zenmanage.flags(), isNotNull);
    });

    test('Zenmanage cacheBackendName returns cache name', () {
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withCache(InMemoryCache())
          .build();

      final zenmanage = Zenmanage(config);

      expect(zenmanage.cacheBackendName, equals('memory'));
    });

    test('Zenmanage clearCache clears the underlying cache', () async {
      final cache = InMemoryCache();
      await cache.setRules('{"flags": {}}');
      final config = ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withCache(cache)
          .build();
      final zenmanage = Zenmanage(config);

      await zenmanage.clearCache();

      expect(await cache.getRules(), isNull);
    });
  });
}
