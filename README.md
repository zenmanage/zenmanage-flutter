# Zenmanage Flutter SDK

[![pub package](https://img.shields.io/pub/v/zenmanage.svg)](https://pub.dev/packages/zenmanage)
[![CI](https://github.com/zenmanage/zenmanage-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/zenmanage/zenmanage-flutter/actions/workflows/ci.yml)
[![Coverage Gate](https://img.shields.io/badge/coverage%20gate-90%25-brightgreen)](https://github.com/zenmanage/zenmanage-flutter/actions/workflows/ci.yml)
[![Dart SDK Version](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![Flutter SDK Version](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev)

The official Dart/Flutter SDK for Zenmanage feature flags and experiments.

Add feature flags to your Flutter app in minutes. Control feature rollouts, A/B test, and manage configurations without deploying code.

## Why Zenmanage?

- 🚀 **Fast**: Rules cached locally - ~1ms evaluation time
- 🎯 **Targeted**: Roll out features to specific users, organizations, or segments  
- 🛡️ **Safe**: Graceful fallbacks and error handling built-in
- 📊 **Insightful**: Automatic usage tracking (optional)
- 🧪 **Testable**: Easy to mock in tests
- ⚡ **Async-first**: Designed for mobile with async/await throughout

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  zenmanage: ^1.0.0
```

Then run:

```bash
flutter pub get
```

**Requirements**:
- Dart 3.0+
- Flutter 3.0+

## Quick Start

### 1. Get Your Mobile Token

Get your mobile token (`mob_...`) from [zenmanage.com](https://zenmanage.com). Mobile tokens are required for Flutter apps.

### 2. Initialize the SDK

```dart
import 'package:zenmanage/zenmanage.dart';

final zenmanage = Zenmanage(
  ConfigBuilder.create()
      .withEnvironmentToken('mob_your_token_here')
      .build(),
);

// Optional: prefetch rules during startup
await zenmanage.initialize();
```

### 3. Check a Feature Flag

```dart
final flag = await zenmanage.flags().single('new-dashboard');

if (flag.isEnabled()) {
  showNewDashboard();
} else {
  showOldDashboard();
}
```

That's it! 🎉

## Flutter Bindings

Use [ZenmanageInitializer] for app-wide async initialization and
[ZenmanageFlagBuilder] for widget-level consumption.

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.zenmanage});

  final Zenmanage zenmanage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ZenmanageInitializer(
        zenmanage: zenmanage,
        loadingBuilder: (_) => const CircularProgressIndicator(),
        child: ZenmanageFlagBuilder(
          flagKey: 'new-dashboard',
          defaultValue: false,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            return snapshot.data!.isEnabled()
                ? const NewDashboard()
                : const OldDashboard();
          },
        ),
      ),
    );
  }
}
```

## Common Use Cases

### Roll Out a New Feature Gradually

```dart
import 'package:zenmanage/zenmanage.dart';

// Create user context
final userContext = Context.user(
  id: 'user_123',
  name: 'John Doe',
  attributes: {'country': 'US', 'plan': 'premium'},
);

// Check if user has access to beta features
final betaAccess = await zenmanage.flags()
    .withContext(userContext)
    .single('beta-program');

if (betaAccess.isEnabled()) {
  enableBetaFeatures();
}
```

### A/B Testing

```dart
final userContext = Context.user(id: userId);

final variant = await zenmanage.flags()
    .withContext(userContext)
    .single('checkout-flow');

if (variant.asString() == 'test_v1') {
  showCheckoutV1();
} else if (variant.asString() == 'test_v2') {
  showCheckoutV2();
} else {
  showCheckoutControl();
}
```

### Multiple Contexts

```dart
final userContext = Context.user(id: 'user_123');
final orgContext = Context.organization(id: 'org_456');

final enterpriseFeature = await zenmanage.flags()
    .withContexts([userContext, orgContext])
    .single('enterprise-analytics');
```

### Handling Missing Flags

```dart
// Option 1: Use singleOrDefault
final flag = await zenmanage.flags().singleOrDefault(
  'optional-feature',
  Flag(key: 'optional-feature', value: false, type: 'boolean'),
);

// Option 2: Use catchError
final flag = await zenmanage.flags()
    .single('optional-feature')
    .catchError((e) => Flag(
      key: 'optional-feature',
      value: false,
      type: 'boolean',
    ));
```

## Type-Safe Value Access

Flags support type-safe accessors:

```dart
final flag = await zenmanage.flags().single('my-flag');

// Boolean access
if (flag.asBool()) { }

// String access
final theme = flag.asString();

// Number access
final limit = flag.asInt();
final timeout = flag.asDouble();

// JSON/Map access
final config = flag.asJson();

// List access
final items = flag.asList<String>();

// Raw value
final value = flag.getValue();
```

## Caching Strategies

### In-Memory Cache (Default)

Fastest but lost on app restart:

```dart
final zenmanage = Zenmanage(
  ConfigBuilder.create()
      .withEnvironmentToken('mob_your_token_here')
      .withCache(InMemoryCache())
      .build(),
);
```

### SharedPreferences Cache (Persistent)

Persists rules across app restarts:

```dart
import 'package:zenmanage/zenmanage.dart';

final cache = SharedPreferencesCache(namespace: 'zenmanage');
await cache.initialize();

final zenmanage = Zenmanage(
  ConfigBuilder.create()
      .withEnvironmentToken('mob_your_token_here')
      .withCache(cache)
      .withCacheTtl(86400) // 24 hours
      .build(),
);
```

### No Cache

Always fresh from API (not recommended for production):

```dart
final zenmanage = Zenmanage(
  ConfigBuilder.create()
      .withEnvironmentToken('mob_your_token_here')
      .withCache(NullCache())
      .build(),
);
```

## Configuration

### Environment Token

Only mobile tokens (`mob_*`) are supported. Client and server tokens are rejected:

```dart
ConfigBuilder.create()
    .withEnvironmentToken('mob_your_token_here') // Required
    .build()
```

### API Endpoint

Override the API endpoint:

```dart
ConfigBuilder.create()
    .withEnvironmentToken('mob_your_token_here')
    .withApiEndpoint('https://api.example.com') // Default: https://api.zenmanage.com
    .build()
```

### Cache TTL

Control how long rules are cached (in seconds):

```dart
ConfigBuilder.create()
    .withEnvironmentToken('mob_your_token_here')
    .withCacheTtl(7200) // 2 hours
    .build()
```

### Usage Reporting

Enable/disable usage reporting (default: enabled):

```dart
ConfigBuilder.create()
    .withEnvironmentToken('mob_your_token_here')
    .withUsageReporting(false) // Disable usage tracking
    .build()
```

## Error Handling

The SDK throws typed exceptions for different error conditions:

```dart
import 'package:zenmanage/zenmanage.dart';

try {
  final flag = await zenmanage.flags().single('my-flag');
} on ConfigurationException catch (e) {
  print('Configuration error: ${e.message}');
} on ApiException catch (e) {
  print('API error (HTTP ${e.statusCode}): ${e.message}');
} on FlagNotFoundException catch (e) {
  print('Flag not found: ${e.message}');
} on TypeConversionException catch (e) {
  print('Type conversion error: ${e.message}');
} on ZenmanageException catch (e) {
  print('General Zenmanage error: ${e.message}');
}
```

## Logging

The SDK logs important events. Configure logging based on your app's logger:

```dart
// Zenmanage logs to stderr by default
// You can capture logs by setting up Flutter's logging
import 'package:logging/logging.dart';

Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((record) {
  print('${record.level.name}: ${record.message}');
});
```

## Testing

### Mock the API

```dart
import 'package:mocktail/mocktail.dart';
import 'package:zenmanage/zenmanage.dart';

void main() {
  test('shows feature when flag is enabled', () async {
    // Use InMemoryCache or NullCache for deterministic tests
    final zenmanage = Zenmanage(
      ConfigBuilder.create()
          .withEnvironmentToken('mob_test_token')
          .withCache(NullCache())
          .build(),
    );

    // Your test here
  });
}
```

### Use Default Values

```dart
void main() {
  test('handles missing flags gracefully', () async {
    final flag = await zenmanage.flags().singleOrDefault(
      'optional-feature',
      Flag(key: 'optional-feature', value: false, type: 'boolean'),
    );

    expect(flag.isEnabled(), isFalse);
  });
}
```

## Examples

See the [example/](example/) directory for complete examples:

- [simple_flags.dart](example/simple_flags.dart) - Basic flag operations
- [context_based_flags.dart](example/context_based_flags.dart) - Using context for personalization
- [ab_testing.dart](example/ab_testing.dart) - A/B testing setup
- [percentage_rollouts.dart](example/percentage_rollouts.dart) - Gradual feature rollouts
- [caching.dart](example/caching.dart) - Caching strategies
- [defaults.dart](example/defaults.dart) - Default values and error handling
- [lib/main.dart](example/lib/main.dart) - Runnable Flutter app example

Run examples with:

```bash
dart example/simple_flags.dart
```

## API Reference

### Zenmanage

Main SDK class:

```dart
class Zenmanage {
  Future<void> initialize({List<Context>? contexts}); // Async startup prefetch
  FlagManager flags(); // Get the flag manager
  String get cacheBackendName; // Get current cache backend name
  Future<void> clearCache(); // Clear all cached rules
}
```

### Flutter Widgets

```dart
class ZenmanageInitializer extends StatefulWidget {
  const ZenmanageInitializer({
    required Zenmanage zenmanage,
    required Widget child,
    List<Context> contexts = const <Context>[],
    WidgetBuilder? loadingBuilder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  });
}

class ZenmanageFlagBuilder extends StatefulWidget {
  const ZenmanageFlagBuilder({
    required String flagKey,
    required Widget Function(BuildContext, AsyncSnapshot<Flag>) builder,
    dynamic defaultValue,
    Context? context,
  });
}
```

### ConfigBuilder

Fluent configuration builder:

```dart
class ConfigBuilder {
  static ConfigBuilder create();
  ConfigBuilder withEnvironmentToken(String token);
  ConfigBuilder withCache(Cache cache);
  ConfigBuilder withApiEndpoint(String endpoint);
  ConfigBuilder withCacheTtl(int ttl);
  ConfigBuilder withUsageReporting(bool enabled);
  Config build();
}
```

### FlagManager

Flag evaluation:

```dart
class FlagManager {
  Future<Flag> single(String flagKey);
  Future<List<Flag>> all();
  Future<Flag> singleOrDefault(String flagKey, Flag defaultFlag);
  FlagManager withContext(Context context);
  FlagManager withContexts(List<Context> contexts);
  FlagManager clearContext();
  Future<void> clearCache();
}
```

### Flag

Feature flag value:

```dart
class Flag {
  String get key;
  dynamic get value;
  String get type;
  
  bool isEnabled();
  dynamic getValue();
  bool asBool();
  String asString();
  num asNumber();
  int asInt();
  double asDouble();
  Map<String, dynamic> asJson();
  List<T> asList<T>();
}
```

### Context

Entity context for targeting:

```dart
class Context {
  factory Context({
    required String type,
    required String identifier,
    String? name,
    Map<String, dynamic>? attributes,
  });
  
  factory Context.user({
    required String id,
    String? name,
    Map<String, dynamic>? attributes,
  });
  
  factory Context.organization({
    required String id,
    String? name,
    Map<String, dynamic>? attributes,
  });
  
  factory Context.account({
    required String id,
    String? name,
    Map<String, dynamic>? attributes,
  });
}
```

## Troubleshooting

### "Invalid environment token"

Ensure you're using a mobile token that starts with `mob_`. Get one from [zenmanage.com](https://zenmanage.com).

### "Flag not found"

Check that the flag key matches exactly (case-sensitive). Use `singleOrDefault` or `catchError` for optional flags.

### No cache persisting

Use `SharedPreferencesCache` instead of `InMemoryCache` for persistence across app restarts.

### Tests fail with API errors

Use `NullCache` and provide default values with `singleOrDefault`.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT - See [LICENSE](LICENSE) file for details

## Support

- 📚 [Documentation](https://github.com/zenmanage/zenmanage-flutter)
- 🐛 [Issue Tracker](https://github.com/zenmanage/zenmanage-flutter/issues)
- 💬 [Discussions](https://github.com/zenmanage/zenmanage-flutter/discussions)
- 🌐 [Zenmanage Website](https://zenmanage.com)
