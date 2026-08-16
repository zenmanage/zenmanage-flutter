/// Tests for cache implementations
import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';

void main() {
  group('InMemoryCache', () {
    test('stores and retrieves rules', () async {
      final cache = InMemoryCache();
      const rules = '{"flags": {"test": true}}';

      final result = await cache.setRules(rules);
      expect(result, isTrue);

      final retrieved = await cache.getRules();
      expect(retrieved, equals(rules));
    });

    test('returns null for unset rules', () async {
      final cache = InMemoryCache();

      final retrieved = await cache.getRules();
      expect(retrieved, isNull);
    });

    test('clears cache', () async {
      final cache = InMemoryCache();
      const rules = '{"flags": {"test": true}}';

      await cache.setRules(rules);
      await cache.clear();

      final retrieved = await cache.getRules();
      expect(retrieved, isNull);
    });

    test('backendName returns "memory"', () {
      final cache = InMemoryCache();
      expect(cache.backendName, equals('memory'));
    });

    test('overwrites existing rules', () async {
      final cache = InMemoryCache();

      await cache.setRules('{"flags": {"old": true}}');
      await cache.setRules('{"flags": {"new": false}}');

      final retrieved = await cache.getRules();
      expect(retrieved, contains('new'));
      expect(retrieved, isNot(contains('old')));
    });
  });

  group('NullCache', () {
    test('always returns null', () async {
      final cache = NullCache();
      const rules = '{"flags": {"test": true}}';

      await cache.setRules(rules);
      final retrieved = await cache.getRules();

      expect(retrieved, isNull);
    });

    test('setRules returns true', () async {
      final cache = NullCache();
      const rules = '{"flags": {"test": true}}';

      final result = await cache.setRules(rules);
      expect(result, isTrue);
    });

    test('clear completes successfully', () async {
      final cache = NullCache();

      expect(() => cache.clear(), isNot(throwsException));
      await cache.clear();
    });

    test('backendName returns "null"', () {
      final cache = NullCache();
      expect(cache.backendName, equals('null'));
    });
  });
}
