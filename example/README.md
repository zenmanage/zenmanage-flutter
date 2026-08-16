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

```bash
dart example/simple_flags.dart
dart example/context_based_flags.dart
dart example/ab_testing.dart
dart example/percentage_rollouts.dart
dart example/caching.dart
dart example/defaults.dart
```

## Running the Flutter app example

```bash
flutter run -t example/lib/main.dart
```

Set your token with a `mob_` token before running against live rules.
