// ignore_for_file: avoid_print -- these scripts print to demonstrate output.
// Caching example
//
// This example demonstrates different caching strategies and fallback patterns.

import 'package:zenmanage/zenmanage.dart';

Future<void> main() async {
  print('=== Caching Strategies ===\n');

  // Example 1: In-memory cache (default, lost on app restart)
  print('1. In-Memory Cache (Ephemeral)\n');

  final zenmanageMemory = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .withCache(InMemoryCache())
        .withCacheTtl(3600) // 1 hour
        .build(),
  );

  print('   Cache Backend: ${zenmanageMemory.cacheBackendName}');
  print('   TTL: 3600 seconds (1 hour)');
  print('   Persistence: Lost on app restart\n');

  try {
    final flag1 = await zenmanageMemory.flags()
        .single('feature-x')
        .catchError((e) => Flag(key: 'feature-x', value: false, type: 'boolean'));
    print('   First fetch: ${flag1.value}');

    // Second fetch from cache
    final flag2 = await zenmanageMemory.flags()
        .single('feature-x')
        .catchError((e) => Flag(key: 'feature-x', value: false, type: 'boolean'));
    print('   Second fetch (cached): ${flag2.value}\n');
  } catch (e) {
    print('   Error: $e\n');
  }

  // Example 2: SharedPreferences cache (persistent, Flutter-specific)
  print('2. SharedPreferences Cache (Persistent)\n');

  try {
    final cache = SharedPreferencesCache(namespace: 'zenmanage');
    await cache.initialize();

    final zenmanagePersistent = Zenmanage(
      ConfigBuilder.create()
          .withEnvironmentToken('mob_your_environment_token_here')
          .withCache(cache)
          .withCacheTtl(86400) // 24 hours
          .build(),
    );

    print('   Cache Backend: ${zenmanagePersistent.cacheBackendName}');
    print('   TTL: 86400 seconds (24 hours)');
    print('   Persistence: Persists across app restarts\n');

    final flag = await zenmanagePersistent.flags()
        .single('feature-y')
        .catchError((e) => Flag(key: 'feature-y', value: true, type: 'boolean'));
    print('   Flag Value: ${flag.value}\n');
  } catch (e) {
    print('   Error: $e\n');
  }

  // Example 3: No cache (always fresh from API)
  print('3. No Cache (Always Fresh)\n');

  final zenmanageNoCache = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .withCache(NullCache())
        .build(),
  );

  print('   Cache Backend: ${zenmanageNoCache.cacheBackendName}');
  print('   Persistence: None');
  print('   Use Case: Testing, development\n');

  // Example 4: Fallback patterns
  print('4. Fallback Patterns\n');

  try {
    // Pattern 1: Use singleOrDefault
    final flag = await zenmanageMemory.flags().singleOrDefault(
      'optional-feature',
      Flag(key: 'optional-feature', value: false, type: 'boolean'),
    );
    print('   singleOrDefault: ${flag.value}');

    // Pattern 2: Catch and provide default
    final flag2 = await zenmanageMemory.flags()
        .single('another-feature')
        .catchError((e) => Flag(
              key: 'another-feature',
              value: 'default',
              type: 'string',
            ));
    print('   catchError with default: ${flag2.value}\n');
  } catch (e) {
    print('   Error: $e\n');
  }

  // Example 5: Cache management
  print('5. Cache Management\n');

  print('   Clearing cache...');
  await zenmanageMemory.clearCache();
  print('   Cache cleared\n');

  print('Examples completed!');
}
