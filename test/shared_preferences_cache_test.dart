// Tests for SharedPreferencesCache
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:zenmanage/zenmanage.dart';

/// A configurable fake platform store so tests can force failures on
/// individual operations without a real platform channel.
class _FakePreferencesStore extends SharedPreferencesStorePlatform {
  _FakePreferencesStore({
    this.failOnGetAll = false,
    this.failOnSetValue = false,
    this.failOnRemove = false,
  });

  final bool failOnGetAll;
  final bool failOnSetValue;
  final bool failOnRemove;
  final Map<String, Object> _data = <String, Object>{};

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) => clear();

  @override
  Future<Map<String, Object>> getAll() async {
    if (failOnGetAll) {
      throw Exception('platform getAll failure');
    }
    return Map<String, Object>.from(_data);
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) =>
      getAll();

  @override
  Future<bool> remove(String key) async {
    if (failOnRemove) {
      throw Exception('platform remove failure');
    }
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failOnSetValue) {
      throw Exception('platform setValue failure');
    }
    _data[key] = value;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.resetStatic();
  });

  group('SharedPreferencesCache', () {
    test('backendName returns "shared_preferences"', () {
      final cache = SharedPreferencesCache();
      expect(cache.backendName, equals('shared_preferences'));
    });

    test('initialize loads the SharedPreferences instance', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();

      await cache.initialize();

      // A subsequent call should not need to re-initialize.
      expect(await cache.getRules(), isNull);
    });

    test('initialize wraps platform errors in CacheException', () async {
      SharedPreferencesStorePlatform.instance =
          _FakePreferencesStore(failOnGetAll: true);
      final cache = SharedPreferencesCache();

      await expectLater(
        cache.initialize(),
        throwsA(isA<CacheException>()),
      );
    });

    test('setRules stores rules and getRules retrieves them', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();
      const rules = '{"flags": {"test": true}}';

      final result = await cache.setRules(rules);
      expect(result, isTrue);

      final retrieved = await cache.getRules();
      expect(retrieved, equals(rules));
    });

    test('setRules lazily initializes when not yet initialized', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();

      final result = await cache.setRules('{"flags": {}}');

      expect(result, isTrue);
    });

    test('setRules wraps platform errors in CacheException', () async {
      SharedPreferencesStorePlatform.instance =
          _FakePreferencesStore(failOnSetValue: true);
      final cache = SharedPreferencesCache();

      await expectLater(
        cache.setRules('{"flags": {}}'),
        throwsA(isA<CacheException>()),
      );
    });

    test('getRules returns null when nothing has been cached', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();

      final retrieved = await cache.getRules();

      expect(retrieved, isNull);
    });

    test('getRules lazily initializes when not yet initialized', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();

      final retrieved = await cache.getRules();

      expect(retrieved, isNull);
    });

    test('getRules wraps platform errors in CacheException', () async {
      SharedPreferencesStorePlatform.instance =
          _FakePreferencesStore(failOnGetAll: true);
      final cache = SharedPreferencesCache();

      await expectLater(
        cache.getRules(),
        throwsA(isA<CacheException>()),
      );
    });

    test('clear removes cached rules', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();
      await cache.setRules('{"flags": {"test": true}}');

      await cache.clear();

      expect(await cache.getRules(), isNull);
    });

    test('clear lazily initializes when not yet initialized', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();

      await cache.clear();
    });

    test('clear wraps platform errors in CacheException', () async {
      SharedPreferencesStorePlatform.instance =
          _FakePreferencesStore(failOnRemove: true);
      final cache = SharedPreferencesCache();
      await cache.initialize();

      await expectLater(
        cache.clear(),
        throwsA(isA<CacheException>()),
      );
    });

    test('default namespace isolates rules under "zenmanage_rules"', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache();
      await cache.setRules('{"flags": {}}');
      await cache.initialize();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zenmanage_rules'), equals('{"flags": {}}'));
    });

    test('custom namespace is prefixed with "zenmanage_"', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cache = SharedPreferencesCache(namespace: 'staging');
      await cache.setRules('{"flags": {}}');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zenmanage_staging'), equals('{"flags": {}}'));
    });

    test('two caches with different namespaces do not collide', () async {
      SharedPreferencesStorePlatform.instance = _FakePreferencesStore();
      final cacheA = SharedPreferencesCache(namespace: 'a');
      final cacheB = SharedPreferencesCache(namespace: 'b');

      await cacheA.setRules('{"flags": {"a": true}}');
      await cacheB.setRules('{"flags": {"b": true}}');

      expect(await cacheA.getRules(), contains('"a"'));
      expect(await cacheB.getRules(), contains('"b"'));
    });
  });
}
