/// Test configuration setup
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
  });
}
