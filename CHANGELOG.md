# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Renamed request headers to the consistent `X-ZEN-` prefix: `X-API-Key` → `X-ZEN-API-KEY`, `X-Default-Value` → `X-ZEN-DEFAULT-VALUE`
- Context is now sent via the `X-ZEN-CONTEXT` header on usage reports instead of the request body, matching the other SDKs and how the server actually reads it

### Fixed
- `FlagManager.single()` now reports the default value on every usage report, not just when the flag falls back to it
- `RuleEngine` no longer drops flags shaped as `{"value": ..., "type": ...}` in a map-keyed `flags` payload
- `RuleEngine` now recognizes the `equals` comparer alias and underscore-spelled comparers like `starts_with`
- `RuleEngine`'s `notnull` comparer now correctly fails (instead of matching) when the target attribute is absent
- Fixed CI, which had never successfully run past its Flutter setup step: an invalid `flutter-version: stable` action input, real `print()` compile errors in the `example/` scripts, and a test bug in `cache_test.dart` that corrupted a subsequent test

## [1.0.0] - 2026-05-08

### Added
- Initial public release of Zenmanage Flutter SDK
- Flag client for Dart and Flutter applications
- Async initialization with automatic API integration
- Local caching with three backends:
  - InMemoryCache (ephemeral, fastest)
  - SharedPreferencesCache (persistent, Flutter-specific)
  - NullCache (no caching, testing-friendly)
- Typed value accessors: `asBool()`, `asString()`, `asNumber()`, `asJson()`, `asList()`
- Context support for personalized flag evaluation
  - User contexts
  - Organization contexts
  - Account contexts
  - Custom attributes
- A/B testing and percentage rollouts
- Gradual feature rollouts
- Error handling with typed exceptions
  - ConfigurationException
  - ApiException
  - FlagNotFoundException
  - TypeConversionException
  - And more
- Comprehensive test suite (90%+ coverage)
- Full API documentation
- Example applications for common use cases:
  - Simple flags
  - Context-based flags
  - A/B testing
  - Percentage rollouts
  - Caching strategies
  - Default values and error handling
- Mobile-only token validation (mob_* tokens)

### Security
- SSL/TLS for all API communication
- Token-based authentication
- No sensitive data stored in logs

### Performance
- ~1ms flag evaluation time with cached rules
- Efficient memory usage
- Async operations to avoid blocking UI

## [Unreleased]

### Planned
- Widget helpers for Flutter integration
- Provider package integration
- Riverpod support
- GetX support
- More advanced rule evaluation
- Offline-first mode with syncing
