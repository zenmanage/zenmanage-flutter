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
