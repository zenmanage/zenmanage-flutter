# Zenmanage Flutter Examples

This directory contains runnable examples for common Zenmanage use cases.

## Examples

- `simple_flags.dart`: Basic flag retrieval and type-safe value access
- `context_based_flags.dart`: User and organization targeting
- `ab_testing.dart`: A/B testing and variant assignment
- `percentage_rollouts.dart`: Gradual rollout strategies
- `caching.dart`: Cache backends and fallback behavior
- `defaults.dart`: Default values and safe error handling
- `lib/main.dart`: Full Flutter app example with app-wide initialization and widget-level flag rendering

## Running script examples

The scripts use the Flutter SDK, so plain `dart` can't load them. Run them from the package root with `flutter test`, which executes each script's `main()` and prints its output:

```bash
flutter test example/simple_flags.dart
flutter test example/context_based_flags.dart
flutter test example/ab_testing.dart
flutter test example/percentage_rollouts.dart
flutter test example/caching.dart
flutter test example/defaults.dart
```

Each script uses the placeholder token `mob_your_environment_token_here`, so the API answers with a 401 and the scripts show their fallback paths. Replace it with your own mobile key (`mob_...`), or a client key (`cli_...`) for Flutter web, to see real flag values.

## Running the Flutter app example

`example/` is a complete Flutter app (Android and iOS) that depends on the SDK in the parent directory:

```bash
cd example
flutter pub get
flutter run
```

Set your environment token in `lib/main.dart` first. It demonstrates app-wide initialization with `ZenmanageInitializer` and widget-level flag rendering with `ZenmanageFlagBuilder`.

## Running the integration test on a real target

`integration_test/zenmanage_test.dart` runs the SDK on a device, simulator, emulator or desktop window. It checks that flags load over real HTTP and that `SharedPreferencesCache` keeps the rules across a restart. It starts its own rules server on the loopback address, so it needs no token and no network.

```bash
cd example
flutter devices                              # pick a target
flutter test integration_test -d <device id>
```

The `Platforms` GitHub Actions workflow runs it on an Android emulator, an iOS simulator, macOS, Linux and Windows for every pull request. The example only commits its `android/` and `ios/` folders, so to run it on a desktop target locally, create that runner first: `flutter create --platforms=macos .` (or `linux`, `windows`). On macOS, also add the `com.apple.security.network.client` and `com.apple.security.network.server` entitlements to `macos/Runner/DebugProfile.entitlements`.

Web isn't covered by this test: a browser can't open a listening socket for the rules server. The workflow builds the example for web instead.
